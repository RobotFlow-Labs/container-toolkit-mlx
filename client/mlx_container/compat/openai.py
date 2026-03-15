"""
OpenAI-compatible API wrapper for MLX Container.

Provides a familiar interface for developers used to the OpenAI Python SDK.

Usage:
    from mlx_container.compat.openai import ChatCompletion

    response = ChatCompletion.create(
        model="mlx-community/Llama-3.2-1B-4bit",
        messages=[
            {"role": "system", "content": "You are a helpful assistant."},
            {"role": "user", "content": "Hello!"},
        ],
    )
    print(response.choices[0].message.content)
"""

import time
import uuid
from dataclasses import dataclass, field
from typing import Iterator, Optional

from mlx_container._grpc_client import get_client
from mlx_container.types import ChatMessage


@dataclass
class Message:
    role: str
    content: str


@dataclass
class Choice:
    index: int
    message: Message
    finish_reason: str = "stop"


@dataclass
class Usage:
    prompt_tokens: int = 0
    completion_tokens: int = 0
    total_tokens: int = 0


@dataclass
class ChatCompletionResponse:
    id: str = ""
    object: str = "chat.completion"
    created: int = 0
    model: str = ""
    choices: list[Choice] = field(default_factory=list)
    usage: Usage = field(default_factory=Usage)


@dataclass
class DeltaChoice:
    index: int
    delta: Message
    finish_reason: Optional[str] = None


@dataclass
class ChatCompletionChunk:
    id: str = ""
    object: str = "chat.completion.chunk"
    created: int = 0
    model: str = ""
    choices: list[DeltaChoice] = field(default_factory=list)


class ChatCompletion:
    """OpenAI-compatible chat completion API."""

    @staticmethod
    def create(
        model: str,
        messages: list[dict],
        max_tokens: int = 512,
        temperature: float = 0.7,
        top_p: float = 1.0,
        stream: bool = False,
    ) -> ChatCompletionResponse | Iterator[ChatCompletionChunk]:
        """
        Create a chat completion, compatible with OpenAI's API.

        Args:
            model: Model ID
            messages: List of message dicts with 'role' and 'content'
            max_tokens: Maximum tokens to generate
            temperature: Sampling temperature
            top_p: Top-p sampling
            stream: If True, return streaming chunks

        Returns:
            ChatCompletionResponse or iterator of ChatCompletionChunk
        """
        chat_msgs = [
            ChatMessage(role=m["role"], content=m["content"])
            for m in messages
        ]

        req_id = f"chatcmpl-{uuid.uuid4().hex[:12]}"
        created = int(time.time())

        if stream:
            return ChatCompletion._stream(
                model, chat_msgs, max_tokens, temperature, top_p, req_id, created
            )

        result = get_client().generate(
            model=model,
            messages=chat_msgs,
            max_tokens=max_tokens,
            temperature=temperature,
            top_p=top_p,
            stream=False,
        )

        return ChatCompletionResponse(
            id=req_id,
            created=created,
            model=model,
            choices=[
                Choice(
                    index=0,
                    message=Message(role="assistant", content=result.text),
                    finish_reason="stop",
                )
            ],
            usage=Usage(
                prompt_tokens=result.prompt_tokens,
                completion_tokens=result.completion_tokens,
                total_tokens=result.prompt_tokens + result.completion_tokens,
            ),
        )

    @staticmethod
    def _stream(
        model, messages, max_tokens, temperature, top_p, req_id, created
    ) -> Iterator[ChatCompletionChunk]:
        token_iter = get_client().generate(
            model=model,
            messages=messages,
            max_tokens=max_tokens,
            temperature=temperature,
            top_p=top_p,
            stream=True,
        )

        for token in token_iter:
            yield ChatCompletionChunk(
                id=req_id,
                created=created,
                model=model,
                choices=[
                    DeltaChoice(
                        index=0,
                        delta=Message(role="assistant", content=token),
                    )
                ],
            )

        # Final chunk with finish_reason
        yield ChatCompletionChunk(
            id=req_id,
            created=created,
            model=model,
            choices=[
                DeltaChoice(
                    index=0,
                    delta=Message(role="assistant", content=""),
                    finish_reason="stop",
                )
            ],
        )
