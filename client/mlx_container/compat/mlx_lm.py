"""
Drop-in replacement for mlx_lm.generate().

Allows existing code that uses mlx_lm to work inside containers
by proxying to the host GPU daemon.

Usage:
    # Instead of: from mlx_lm import generate
    from mlx_container.compat.mlx_lm import generate

    result = generate(model, tokenizer, prompt="Hello world")
"""

from typing import Any, Optional

from mlx_container._grpc_client import get_client
from mlx_container.types import GenerateResult


def load(model_id: str, **kwargs) -> tuple:
    """
    Load a model. Returns (model_id, None) as a stand-in for (model, tokenizer).

    In the container, the actual model lives on the host — we just need the ID.
    """
    get_client().load_model(model_id)
    return (model_id, None)


def generate(
    model: Any,
    tokenizer: Any = None,
    prompt: str = "",
    max_tokens: int = 512,
    temp: float = 0.7,
    top_p: float = 1.0,
    **kwargs,
) -> str:
    """
    Generate text, compatible with mlx_lm.generate() signature.

    Args:
        model: Model ID string (or tuple from load())
        tokenizer: Ignored (tokenizer runs on host)
        prompt: Text prompt
        max_tokens: Maximum tokens
        temp: Temperature
        top_p: Top-p sampling

    Returns:
        Generated text string
    """
    model_id = model if isinstance(model, str) else model[0] if isinstance(model, tuple) else str(model)

    result = get_client().generate(
        prompt=prompt,
        model=model_id,
        max_tokens=max_tokens,
        temperature=temp,
        top_p=top_p,
        stream=False,
    )
    return result.text
