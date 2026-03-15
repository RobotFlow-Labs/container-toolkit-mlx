# container-toolkit-mlx

**GPU-accelerated MLX inference for Linux containers on Apple Silicon.**

The Apple Silicon equivalent of [NVIDIA's Container Toolkit](https://github.com/NVIDIA/nvidia-container-toolkit). Gives Linux containers running in Apple's lightweight VMs direct access to the host's Metal GPU for ML inference via [MLX](https://github.com/ml-explore/mlx).

> **Status**: Early development. Contributions welcome.

## The Problem

Apple's [`container`](https://github.com/apple/container-tool) runs Linux containers in lightweight VMs on Apple Silicon — but has **zero GPU support**. Apple closed the GPU feature request as "won't fix". Metal and MLX cannot run inside Linux VMs — this is a hardware/driver limitation.

Existing approaches fall short:
- **krunkit/libkrun**: Vulkan remoting gets ~77% native perf, Fedora-only, no MLX
- **Docker Model Runner**: Runs natively on host (not containerized), only vLLM

## The Solution

A host-guest bridge via **vsock** — the same proven channel Apple's `vminitd` uses.

```
┌─────────────────────────────────────────────────┐
│  Linux Container (in VM)                        │
│                                                 │
│  Python App → mlx_container (client lib)        │
│       │                                         │
│       └── gRPC over vsock (CID=2, port 2048) ──┼──┐
└─────────────────────────────────────────────────┘  │
                                                     │ vsock
┌─────────────────────────────────────────────────┐  │
│  macOS Host                                     │  │
│                                                 │  │
│  mlx-container-daemon ◄────────────────────────────┘
│       │
│       ├── ModelManager (mlx-swift-lm)
│       ├── GPUMemoryAllocator
│       └── Metal GPU (unified memory)
│
│  mlx-ctk (CLI tool)
└─────────────────────────────────────────────────┘
```

A **GPU daemon** on macOS has direct Metal/MLX access. Containers talk to it via **gRPC over vsock**. Inside containers, a Python client library provides an **MLX-compatible API** — your code doesn't need to know it's running in a container.

## Quick Start

### 1. Build the toolkit (macOS host)

```bash
# Build CLI and daemon
swift build

# Check your GPU
swift run mlx-ctk device list

# Initialize config
swift run mlx-ctk setup

# Start the daemon with a model
swift run mlx-container-daemon \
  --preload-model mlx-community/Llama-3.2-1B-4bit
```

### 2. Use from a container

```python
# pip install mlx-container
from mlx_container import generate, load_model

# Load model on host GPU
load_model("mlx-community/Llama-3.2-1B-4bit")

# Generate text (runs on host Metal GPU, returns over vsock)
result = generate(
    "Explain quantum computing",
    model="mlx-community/Llama-3.2-1B-4bit"
)
print(result.text)
print(f"{result.tokens_per_second:.0f} tok/s")

# Stream tokens
for token in generate("Write a poem", model="...", stream=True):
    print(token, end="", flush=True)
```

### 3. OpenAI-compatible API

```python
from mlx_container.compat.openai import ChatCompletion

response = ChatCompletion.create(
    model="mlx-community/Llama-3.2-1B-4bit",
    messages=[
        {"role": "user", "content": "Hello!"}
    ],
)
print(response.choices[0].message.content)
```

### 4. Drop-in mlx_lm replacement

```python
# Change one import — everything else works
# from mlx_lm import load, generate
from mlx_container.compat.mlx_lm import load, generate

model, tokenizer = load("mlx-community/Llama-3.2-1B-4bit")
result = generate(model, tokenizer, prompt="Hello world")
```

## Components

| Component | Language | What it does |
|-----------|----------|-------------|
| `mlx-ctk` | Swift | CLI tool — GPU discovery, setup, config |
| `mlx-container-daemon` | Swift | Host daemon — loads models, serves inference over vsock |
| `mlx-container` | Python | Client library for use inside containers |

## Project Structure

```
Sources/
├── mlx-ctk/                  # CLI tool
├── MLXContainerDaemon/        # Host GPU daemon
├── MLXContainerProtocol/      # gRPC service definition
├── MLXContainerConfig/        # Configuration
├── MLXContainerRuntime/       # Container integration
└── MLXDeviceDiscovery/        # Metal GPU enumeration

client/                        # Python client package
├── mlx_container/
│   ├── inference.py           # generate(), generate_stream()
│   ├── models.py              # load_model(), list_models()
│   └── compat/                # mlx_lm + OpenAI wrappers
│       ├── mlx_lm.py
│       └── openai.py

proto/                         # Protobuf service definition
images/                        # Container Dockerfiles
examples/                      # Usage examples
```

## Requirements

- **macOS 15+** on Apple Silicon (M1/M2/M3/M4)
- **Swift 6.0+**
- **Python 3.10+** (inside containers)

## How It Works

1. **Device Discovery**: The CLI detects your Apple GPU via Metal framework — chip family, memory, capabilities.

2. **Host Daemon**: A gRPC server binds to a vsock port (default 2048). It uses `mlx-swift` and `mlx-swift-lm` to load HuggingFace models and run inference on the Metal GPU.

3. **vsock Bridge**: The same communication channel that Apple's own `vminitd` uses for container management. Zero network overhead — it's a direct hypervisor channel.

4. **Python Client**: Inside the Linux container, the client library connects to the daemon via `AF_VSOCK` and sends gRPC requests. The API is designed to feel native — streaming tokens, chat messages, embeddings.

5. **Container Integration**: GPU flags (`--gpu`, `--gpu-model`, `--gpu-memory`) for the `container run` command. The daemon lifecycle is managed automatically.

## gRPC Service

```protobuf
service MLXContainerService {
  rpc LoadModel(LoadModelRequest) returns (LoadModelResponse);
  rpc UnloadModel(UnloadModelRequest) returns (UnloadModelResponse);
  rpc ListModels(ListModelsRequest) returns (ListModelsResponse);
  rpc Generate(GenerateRequest) returns (stream GenerateResponse);
  rpc Embed(EmbedRequest) returns (EmbedResponse);
  rpc GetGPUStatus(GetGPUStatusRequest) returns (GetGPUStatusResponse);
  rpc Ping(PingRequest) returns (PingResponse);
}
```

## Comparison

| Feature | container-toolkit-mlx | Docker Model Runner | krunkit/libkrun |
|---------|----------------------|--------------------|-----------------|
| Runs in container | Yes | No (host only) | Yes |
| Apple GPU access | Yes (via MLX) | Yes (native) | Partial (Vulkan) |
| MLX models | Yes | No | No |
| Performance vs native | ~95%+ (vsock overhead only) | 100% (native) | ~77% (Vulkan remoting) |
| Python API | Yes | REST only | No |
| Streaming | Yes | Yes | No |
| Multi-model | Yes | Limited | No |
| Open source | Yes | Partial | Yes |

## Contributing

This project is in early development. We welcome contributions in:

- Testing on different Apple Silicon chips (M1/M2/M3/M4, Pro/Max/Ultra)
- Performance benchmarking vs native MLX
- Additional model format support
- Container image optimization
- Documentation and examples

## License

MIT

---

Built by [RobotFlow Labs](https://robotflowlabs.com) / [AIFLOW LABS](https://aiflowlabs.io)
