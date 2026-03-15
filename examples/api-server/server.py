#!/usr/bin/env python3
"""
FastAPI inference server running inside a Linux container,
using the host Apple GPU via MLX Container Toolkit.

Usage (inside container):
    container run --gpu --gpu-model mlx-community/Llama-3.2-1B-4bit \\
        -p 8000:8000 \\
        ghcr.io/robotflow-labs/mlx-python:latest \\
        python3 server.py

Usage (local dev mode):
    python3 server.py --host 0.0.0.0 --port 8000

Then from the host:
    curl http://localhost:8000/health
    curl http://localhost:8000/v1/models
    curl http://localhost:8000/v1/chat/completions \\
        -H "Content-Type: application/json" \\
        -d '{"model": "mlx-community/Llama-3.2-1B-4bit", "messages": [{"role": "user", "content": "Hello!"}]}'

Environment variables:
    SERVER_HOST        Bind host (default: 0.0.0.0)
    SERVER_PORT        Bind port (default: 8000)
    MLX_DAEMON_HOST    Daemon TCP host for dev mode
    MLX_DAEMON_PORT    Daemon TCP port for dev mode
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import uuid
from typing import AsyncIterator

from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field

from mlx_container.compat.openai import ChatCompletion


# ---------------------------------------------------------------------------
# App
# ---------------------------------------------------------------------------

app = FastAPI(
    title="MLX Container API",
    description=(
        "OpenAI-compatible inference API backed by Apple Silicon GPU "
        "via the MLX Container Toolkit."
    ),
    version="0.1.0",
)

# CORS: allow all origins so browsers and local dev tools can reach the API.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ---------------------------------------------------------------------------
# Request / response models
# ---------------------------------------------------------------------------

class ChatMessage(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    model: str
    messages: list[ChatMessage]
    max_tokens: int = Field(default=512, ge=1, le=32768)
    temperature: float = Field(default=0.7, ge=0.0, le=2.0)
    top_p: float = Field(default=1.0, ge=0.0, le=1.0)
    stream: bool = False


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.get("/health", summary="Daemon health check")
async def health() -> dict:
    """
    Return daemon connectivity status and GPU info.

    Raises HTTP 503 when the daemon cannot be reached so that load
    balancers and container orchestrators can detect unhealthy replicas.
    """
    from mlx_container._grpc_client import get_client

    try:
        client = get_client()
        ping = client.ping()
        gpu = client.get_gpu_status()
        return {
            "status": "ok",
            "daemon": ping,
            "gpu": {
                "device": gpu.device_name,
                "family": gpu.gpu_family,
                "total_memory_gb": round(gpu.total_memory_bytes / 1024**3, 2),
                "used_memory_gb": round(gpu.used_memory_bytes / 1024**3, 2),
                "loaded_models": gpu.loaded_models_count,
            },
        }
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"MLX Container Daemon unreachable: {exc}",
        )


@app.get("/v1/models", summary="List loaded models (OpenAI-compatible)")
async def list_models_endpoint() -> dict:
    """Return models currently loaded on the host GPU."""
    from mlx_container import list_models

    try:
        models = list_models()
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Failed to list models: {exc}",
        )

    return {
        "object": "list",
        "data": [
            {
                "id": m.model_id,
                "object": "model",
                "created": int(time.time()),
                "owned_by": "mlx-container",
                "permission": [],
                "root": m.model_id,
                "parent": None,
                "loaded": m.is_loaded,
                "memory_used_gb": round(m.memory_used_bytes / 1024**3, 3),
            }
            for m in models
        ],
    }


@app.post("/v1/chat/completions", summary="Chat completion (OpenAI-compatible)")
async def chat_completions(request: ChatRequest):
    """
    Generate a chat completion using the host GPU.

    Supports streaming via ``"stream": true`` — returns Server-Sent Events
    in the same format as the OpenAI API.
    """
    messages = [{"role": m.role, "content": m.content} for m in request.messages]

    if request.stream:
        return StreamingResponse(
            _stream_response(
                request.model,
                messages,
                request.max_tokens,
                request.temperature,
                request.top_p,
            ),
            media_type="text/event-stream",
            headers={
                "Cache-Control": "no-cache",
                "X-Accel-Buffering": "no",
            },
        )

    try:
        response = ChatCompletion.create(
            model=request.model,
            messages=messages,
            max_tokens=request.max_tokens,
            temperature=request.temperature,
            top_p=request.top_p,
            stream=False,
        )
    except RuntimeError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Inference failed: {exc}",
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


# ---------------------------------------------------------------------------
# Streaming helper
# ---------------------------------------------------------------------------

async def _stream_response(
    model: str,
    messages: list[dict],
    max_tokens: int,
    temperature: float,
    top_p: float,
) -> AsyncIterator[str]:
    """Yield SSE-formatted chunks from the MLX token stream."""
    try:
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
    except Exception as exc:
        error_payload = {"error": {"message": str(exc), "type": "server_error"}}
        yield f"data: {json.dumps(error_payload)}\n\n"

    yield "data: [DONE]\n\n"


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="MLX Container API Server — OpenAI-compatible FastAPI server",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "--host",
        default=os.environ.get("SERVER_HOST", "0.0.0.0"),
        help="Bind host. Override with SERVER_HOST env var.",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=int(os.environ.get("SERVER_PORT", "8000")),
        help="Bind port. Override with SERVER_PORT env var.",
    )
    parser.add_argument(
        "--reload",
        action="store_true",
        default=False,
        help="Enable auto-reload for development.",
    )
    return parser.parse_args()


if __name__ == "__main__":
    try:
        import uvicorn
    except ImportError:
        print(
            "uvicorn not found. Install it with: pip install uvicorn[standard]",
            file=sys.stderr,
        )
        sys.exit(1)

    args = _parse_args()
    print(f"Starting MLX Container API on http://{args.host}:{args.port}")
    uvicorn.run(
        "server:app",
        host=args.host,
        port=args.port,
        reload=args.reload,
    )
