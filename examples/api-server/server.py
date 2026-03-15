#!/usr/bin/env python3
"""
FastAPI inference server running inside a Linux container,
using the host Apple GPU via MLX Container Toolkit.

Usage:
    container run --gpu --gpu-model mlx-community/Llama-3.2-1B-4bit \
        -p 8000:8000 \
        ghcr.io/robotflow-labs/mlx-python:latest \
        python3 server.py

Then call from the host:
    curl http://localhost:8000/v1/chat/completions \
        -H "Content-Type: application/json" \
        -d '{"model": "mlx-community/Llama-3.2-1B-4bit", "messages": [{"role": "user", "content": "Hello!"}]}'
"""

from fastapi import FastAPI
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
import json
import time
import uuid

from mlx_container.compat.openai import ChatCompletion

app = FastAPI(
    title="MLX Container API",
    description="OpenAI-compatible API backed by Apple Silicon GPU via MLX Container Toolkit",
    version="0.1.0",
)


class ChatMessage(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    model: str
    messages: list[ChatMessage]
    max_tokens: int = 512
    temperature: float = 0.7
    top_p: float = 1.0
    stream: bool = False


@app.get("/health")
async def health():
    from mlx_container._grpc_client import get_client
    ping = get_client().ping()
    return {"status": "ok", "daemon": ping}


@app.get("/v1/models")
async def list_models():
    from mlx_container import list_models
    models = list_models()
    return {
        "object": "list",
        "data": [
            {
                "id": m.model_id,
                "object": "model",
                "owned_by": "mlx-container",
            }
            for m in models
        ],
    }


@app.post("/v1/chat/completions")
async def chat_completions(request: ChatRequest):
    messages = [{"role": m.role, "content": m.content} for m in request.messages]

    if request.stream:
        return StreamingResponse(
            _stream_response(request.model, messages, request.max_tokens, request.temperature, request.top_p),
            media_type="text/event-stream",
        )

    response = ChatCompletion.create(
        model=request.model,
        messages=messages,
        max_tokens=request.max_tokens,
        temperature=request.temperature,
        top_p=request.top_p,
        stream=False,
    )

    return {
        "id": response.id,
        "object": "chat.completion",
        "created": response.created,
        "model": response.model,
        "choices": [
            {
                "index": c.index,
                "message": {"role": c.message.role, "content": c.message.content},
                "finish_reason": c.finish_reason,
            }
            for c in response.choices
        ],
        "usage": {
            "prompt_tokens": response.usage.prompt_tokens,
            "completion_tokens": response.usage.completion_tokens,
            "total_tokens": response.usage.total_tokens,
        },
    }


async def _stream_response(model, messages, max_tokens, temperature, top_p):
    chunks = ChatCompletion.create(
        model=model,
        messages=messages,
        max_tokens=max_tokens,
        temperature=temperature,
        top_p=top_p,
        stream=True,
    )

    for chunk in chunks:
        data = {
            "id": chunk.id,
            "object": "chat.completion.chunk",
            "created": chunk.created,
            "model": chunk.model,
            "choices": [
                {
                    "index": c.index,
                    "delta": {"role": c.delta.role, "content": c.delta.content},
                    "finish_reason": c.finish_reason,
                }
                for c in chunk.choices
            ],
        }
        yield f"data: {json.dumps(data)}\n\n"

    yield "data: [DONE]\n\n"


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
