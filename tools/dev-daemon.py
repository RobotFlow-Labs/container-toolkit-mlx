#!/usr/bin/env python3
"""
Development daemon — Python-based MLX inference server for testing.

Uses the same JSON-over-gRPC protocol as the Swift daemon, but runs
directly with Python MLX (no Xcode required for Metal shader compilation).

Usage:
    python3 tools/dev-daemon.py --model mlx-community/SmolLM-135M-Instruct-4bit

This is for development/testing only. The production daemon is the Swift binary.
"""

import argparse
import json
import time
import sys
from concurrent import futures
from http.server import HTTPServer, BaseHTTPRequestHandler

# Check MLX availability
try:
    import mlx.core as mx
    from mlx_lm import load, generate
    from mlx_lm.utils import generate_step
except ImportError:
    print("ERROR: mlx and mlx-lm required. Install with: pip install mlx mlx-lm")
    sys.exit(1)


MAX_TOKENS_CAP = 4096  # Hard cap on max_tokens per request
MODEL_ID_PATTERN = r'^[a-zA-Z0-9_-]+/[a-zA-Z0-9._-]+$'


def _validate_model_id(model_id: str) -> str:
    """Validate model ID format to prevent path traversal."""
    import re
    if not model_id or not re.match(MODEL_ID_PATTERN, model_id):
        raise ValueError(f"Invalid model ID format: {model_id!r}. Expected 'owner/model-name'.")
    if '..' in model_id:
        raise ValueError(f"Model ID must not contain '..': {model_id!r}")
    return model_id


class ModelManager:
    """Simple model manager for development."""

    def __init__(self):
        self.models: dict[str, tuple] = {}  # model_id -> (model, tokenizer)
        self.start_time = time.time()

    def load_model(self, model_id: str) -> dict:
        model_id = _validate_model_id(model_id)
        if model_id in self.models:
            return {"success": True, "modelID": model_id, "loadTimeSeconds": 0}

        start = time.time()
        print(f"Loading model: {model_id}...")
        model, tokenizer = load(model_id)
        elapsed = time.time() - start
        self.models[model_id] = (model, tokenizer)
        print(f"Model loaded in {elapsed:.2f}s")

        return {
            "success": True,
            "modelID": model_id,
            "loadTimeSeconds": elapsed,
        }

    def unload_model(self, model_id: str) -> dict:
        if model_id in self.models:
            del self.models[model_id]
            return {"success": True}
        return {"success": False, "error": f"Model not loaded: {model_id}"}

    def list_models(self) -> dict:
        return {
            "models": [
                {"modelID": mid, "isLoaded": True, "modelType": "llm"}
                for mid in self.models
            ]
        }

    def generate(self, model_id: str, prompt: str, max_tokens: int = 256,
                 temperature: float = 0.7) -> dict:
        max_tokens = min(max_tokens, MAX_TOKENS_CAP)
        if model_id not in self.models:
            raise ValueError(f"Model not loaded: {model_id}")

        model, tokenizer = self.models[model_id]
        start = time.time()
        result = generate(
            model, tokenizer,
            prompt=prompt,
            max_tokens=max_tokens,
            temp=temperature,
        )
        elapsed = time.time() - start
        # Count tokens approximately
        tokens = len(tokenizer.encode(result))

        return {
            "fullText": result,
            "promptTokens": len(tokenizer.encode(prompt)),
            "completionTokens": tokens,
            "promptTimeSeconds": 0.0,
            "generationTimeSeconds": elapsed,
            "tokensPerSecond": tokens / elapsed if elapsed > 0 else 0,
        }

    def get_gpu_status(self) -> dict:
        return {
            "deviceName": str(mx.default_device()),
            "totalMemoryBytes": 0,
            "gpuFamily": "metal",
            "loadedModelsCount": len(self.models),
            "loadedModels": [
                {"modelID": mid, "isLoaded": True, "modelType": "llm"}
                for mid in self.models
            ],
        }

    def ping(self) -> dict:
        return {
            "status": "ok",
            "version": "0.1.0-dev",
            "uptimeSeconds": time.time() - self.start_time,
        }


# Simple HTTP/JSON server (same endpoints, easier to test than gRPC)
manager = ModelManager()


MAX_REQUEST_BYTES = 1024 * 1024  # 1 MB max request body


class DaemonHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers.get("Content-Length", 0))
        if content_length > MAX_REQUEST_BYTES:
            self.send_error(413, "Request body too large")
            return
        body = json.loads(self.rfile.read(content_length)) if content_length > 0 else {}

        try:
            if self.path == "/LoadModel":
                result = manager.load_model(body.get("modelID", ""))
            elif self.path == "/UnloadModel":
                result = manager.unload_model(body.get("modelID", ""))
            elif self.path == "/ListModels":
                result = manager.list_models()
            elif self.path == "/Generate":
                params = body.get("parameters", {})
                result = manager.generate(
                    model_id=body.get("modelID", ""),
                    prompt=body.get("prompt", ""),
                    max_tokens=params.get("maxTokens", 256),
                    temperature=params.get("temperature", 0.7),
                )
            elif self.path == "/GetGPUStatus":
                result = manager.get_gpu_status()
            elif self.path == "/Ping":
                result = manager.ping()
            else:
                self.send_error(404)
                return

            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(result).encode())

        except Exception as e:
            self.send_response(500)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": str(e)}).encode())

    def log_message(self, format, *args):
        print(f"[{time.strftime('%H:%M:%S')}] {format % args}")


def main():
    parser = argparse.ArgumentParser(description="MLX Container Dev Daemon")
    parser.add_argument("--port", type=int, default=50051, help="HTTP port")
    parser.add_argument("--model", type=str, help="Model to pre-load")
    args = parser.parse_args()

    print(f"GPU: {mx.default_device()}")

    if args.model:
        manager.load_model(args.model)

    print(f"\nDev daemon listening on http://localhost:{args.port}")
    print("Endpoints: /Ping /LoadModel /Generate /ListModels /GetGPUStatus\n")

    server = HTTPServer(("127.0.0.1", args.port), DaemonHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down.")


if __name__ == "__main__":
    main()
