# container-toolkit-mlx

GPU-accelerated MLX inference toolkit for Linux containers on Apple Silicon. Host-guest bridge via vsock — a GPU daemon on macOS serves Metal/MLX inference to containers over gRPC.

## Architecture

```
Linux Container (VM) → gRPC over vsock → macOS Host Daemon → Metal GPU (MLX)
```

## Dev Commands

```bash
# Build everything
swift build

# Build specific targets
swift build --product mlx-ctk
swift build --product mlx-container-daemon

# Run CLI
swift run mlx-ctk device list
swift run mlx-ctk setup
swift run mlx-ctk config show

# Run daemon
swift run mlx-container-daemon --port 2048 --preload-model mlx-community/Llama-3.2-1B-4bit

# Python client (inside container)
cd client && pip install -e .
python -c "from mlx_container import generate; print(generate('Hello', model='...'))"
```

## Project Structure

| Directory | Purpose |
|-----------|---------|
| `Sources/MLXDeviceDiscovery/` | Metal GPU enumeration |
| `Sources/MLXContainerConfig/` | Toolkit + per-container config |
| `Sources/MLXContainerProtocol/` | gRPC service definition + protobuf messages |
| `Sources/MLXContainerDaemon/` | Host daemon (gRPC server, model manager, inference engine) |
| `Sources/mlx-ctk/` | CLI tool (`mlx-ctk device list`, `setup`, `config`) |
| `Sources/MLXContainerRuntime/` | Container integration (GPU flags, daemon lifecycle, vsock relay) |
| `client/` | Python client package (`mlx-container`) |
| `proto/` | Protobuf service definition |
| `images/` | Dockerfiles for container images |
| `examples/` | Example scripts (hello-mlx, api-server) |
| `repositories/` | Cloned reference repos (gitignored) |
| `apple-container/` | Reference: Apple's container CLI |
| `apple-containerization/` | Reference: Apple's containerization framework |

## Key Dependencies

### Swift
- `mlx-swift`, `mlx-swift-lm` — Apple's MLX framework
- `grpc-swift-2`, `grpc-swift-nio-transport` — gRPC over vsock
- `swift-argument-parser` — CLI
- `swift-protobuf` — serialization

### Python
- `grpcio`, `protobuf` — gRPC client
- No MLX dependency (runs in Linux, GPU ops proxied to host)

## Conventions

- Follow AIFLOW LABS coding standards
- Prefer `uv` for Python package management
- Use `rg` (ripgrep) over `grep`
- Swift 6 with strict concurrency (Sendable, actors)
- vsock port 2048 default, CID 2 = host

# currentDate
Today's date is 2026-03-15.
