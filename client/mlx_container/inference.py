"""High-level inference API."""

from typing import Iterator, Optional

from mlx_container._grpc_client import get_client
from mlx_container.types import GenerateResult, ChatMessage


def generate(
    prompt: str = "",
    model: str = "",
    messages: Optional[list[ChatMessage]] = None,
    max_tokens: int = 512,
    temperature: float = 0.7,
    top_p: float = 1.0,
    stream: bool = False,
) -> GenerateResult | Iterator[str]:
    """
    Generate text using the host Apple GPU via MLX.

    This function runs inside a Linux container but leverages the host's
    Metal GPU through the MLX Container Daemon over vsock.

    Args:
        prompt: Text prompt for completion
        model: Model ID (e.g. "mlx-community/Llama-3.2-1B-4bit")
        messages: Chat messages for conversational use
        max_tokens: Maximum tokens to generate
        temperature: Sampling temperature (0.0 = deterministic)
        top_p: Top-p (nucleus) sampling
        stream: If True, returns an iterator yielding tokens

    Returns:
        GenerateResult with full text and stats, or token iterator if stream=True

    Example:
        >>> result = generate("Explain quantum computing", model="mlx-community/Llama-3.2-1B-4bit")
        >>> print(result.text)

        >>> for token in generate("Write a haiku", model="mlx-community/Llama-3.2-1B-4bit", stream=True):
        ...     print(token, end="", flush=True)
    """
    return get_client().generate(
        prompt=prompt,
        model=model,
        messages=messages,
        max_tokens=max_tokens,
        temperature=temperature,
        top_p=top_p,
        stream=stream,
    )


def generate_stream(
    prompt: str = "",
    model: str = "",
    messages: Optional[list[ChatMessage]] = None,
    max_tokens: int = 512,
    temperature: float = 0.7,
    top_p: float = 1.0,
) -> Iterator[str]:
    """
    Stream tokens from the host GPU. Convenience wrapper for generate(stream=True).

    Calls the client directly with stream=True and validates the return type
    at runtime to catch any future interface drift early.

    Yields:
        Individual tokens as strings

    Raises:
        TypeError: If the client does not return an iterator when stream=True.
    """
    result = get_client().generate(
        prompt=prompt,
        model=model,
        messages=messages,
        max_tokens=max_tokens,
        temperature=temperature,
        top_p=top_p,
        stream=True,
    )
    if not hasattr(result, "__iter__") or not hasattr(result, "__next__"):
        raise TypeError(
            f"generate(stream=True) must return an iterator, got {type(result).__name__!r}. "
            "The client interface may have changed."
        )
    yield from result
