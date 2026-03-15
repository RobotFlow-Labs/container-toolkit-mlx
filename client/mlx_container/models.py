"""Model management high-level API."""

from mlx_container._grpc_client import get_client
from mlx_container.types import ModelInfo


def load_model(
    model_id: str,
    alias: str = "",
    memory_budget_bytes: int = 0,
) -> bool:
    """
    Load a model on the host GPU.

    Args:
        model_id: HuggingFace model ID (e.g. "mlx-community/Llama-3.2-1B-4bit")
        alias: Optional short alias for the model
        memory_budget_bytes: GPU memory budget (0 = auto)

    Returns:
        True if successful

    Example:
        >>> load_model("mlx-community/Llama-3.2-1B-4bit")
        True
    """
    return get_client().load_model(model_id, alias, memory_budget_bytes)


def unload_model(model_id: str) -> bool:
    """
    Unload a model from the host GPU.

    Args:
        model_id: Model ID to unload

    Returns:
        True if successful
    """
    return get_client().unload_model(model_id)


def list_models() -> list[ModelInfo]:
    """
    List all models loaded on the host GPU.

    Returns:
        List of ModelInfo objects
    """
    return get_client().list_models()
