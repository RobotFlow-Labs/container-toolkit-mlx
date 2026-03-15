"""
MLX Container — GPU-accelerated inference client for Linux containers on Apple Silicon.

Usage inside a Linux container:

    from mlx_container import generate, load_model, list_models

    # Load a model on the host GPU
    load_model("mlx-community/Llama-3.2-1B-4bit")

    # Generate text (runs on host Metal GPU, returns over vsock)
    result = generate("Explain quantum computing", model="mlx-community/Llama-3.2-1B-4bit")
    print(result)

    # Stream tokens
    for token in generate("Write a poem", model="mlx-community/Llama-3.2-1B-4bit", stream=True):
        print(token, end="", flush=True)
"""

from mlx_container.inference import generate, generate_stream
from mlx_container.models import load_model, unload_model, list_models
from mlx_container.types import GenerateResult, ModelInfo, GPUStatus
from mlx_container._grpc_client import MLXContainerClient

__version__ = "0.1.0"
__all__ = [
    "generate",
    "generate_stream",
    "load_model",
    "unload_model",
    "list_models",
    "GenerateResult",
    "ModelInfo",
    "GPUStatus",
    "MLXContainerClient",
]
