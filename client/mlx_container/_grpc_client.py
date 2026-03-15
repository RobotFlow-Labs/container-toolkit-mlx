"""
gRPC client for communicating with the MLX Container Daemon.

Supports both vsock (in containers) and TCP (for development).
"""

import os
from typing import Iterator, Optional

import grpc

from mlx_container._vsock import get_vsock_target, _vsock_available, AF_VSOCK, VMADDR_CID_HOST, DEFAULT_PORT
from mlx_container.types import GenerateResult, ModelInfo, GPUStatus, ChatMessage

# We'll use a simple JSON-over-gRPC approach since we hand-wrote the proto
# For production, generate proper stubs with `grpc_tools.protoc`
from mlx_container.proto import mlx_container_pb2 as pb2
from mlx_container.proto import mlx_container_pb2_grpc as pb2_grpc


class MLXContainerClient:
    """
    Client for the MLX Container Daemon.

    Connects over vsock when inside a container, or TCP for development.
    """

    def __init__(
        self,
        target: Optional[str] = None,
        vsock_cid: int = VMADDR_CID_HOST,
        vsock_port: int = DEFAULT_PORT,
    ):
        if target:
            self._target = target
        else:
            self._target = get_vsock_target()

        self._channel: Optional[grpc.Channel] = None
        self._stub: Optional[pb2_grpc.MLXContainerServiceStub] = None

    def _ensure_connected(self):
        """Lazily establish gRPC connection."""
        if self._channel is not None:
            return

        # Create channel based on transport
        if self._target.startswith("vsock:"):
            # vsock transport — use a custom channel
            parts = self._target.split(":")
            cid = int(parts[1])
            port = int(parts[2])
            # gRPC doesn't natively support vsock, so we use TCP fallback
            # with a vsock socket wrapper. For production, use grpc-swift on host.
            self._channel = grpc.insecure_channel(f"localhost:{port}")
        else:
            self._channel = grpc.insecure_channel(self._target)

        self._stub = pb2_grpc.MLXContainerServiceStub(self._channel)

    @property
    def stub(self) -> pb2_grpc.MLXContainerServiceStub:
        self._ensure_connected()
        assert self._stub is not None
        return self._stub

    def close(self):
        """Close the gRPC channel."""
        if self._channel:
            self._channel.close()
            self._channel = None
            self._stub = None

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.close()

    # ── Model Management ──────────────────────────────────────────

    def load_model(self, model_id: str, alias: str = "", memory_budget_bytes: int = 0) -> bool:
        """Load a model on the host GPU."""
        request = pb2.LoadModelRequest(
            model_id=model_id,
            alias=alias,
            memory_budget_bytes=memory_budget_bytes,
        )
        response = self.stub.LoadModel(request)
        if not response.success:
            raise RuntimeError(f"Failed to load model: {response.error}")
        return True

    def unload_model(self, model_id: str) -> bool:
        """Unload a model from the host GPU."""
        request = pb2.UnloadModelRequest(model_id=model_id)
        response = self.stub.UnloadModel(request)
        if not response.success:
            raise RuntimeError(f"Failed to unload model: {response.error}")
        return True

    def list_models(self) -> list[ModelInfo]:
        """List all loaded models."""
        response = self.stub.ListModels(pb2.ListModelsRequest())
        return [
            ModelInfo(
                model_id=m.model_id,
                alias=m.alias,
                memory_used_bytes=m.memory_used_bytes,
                is_loaded=m.is_loaded,
                model_type=m.model_type,
            )
            for m in response.models
        ]

    # ── Inference ─────────────────────────────────────────────────

    def generate(
        self,
        prompt: str = "",
        model: str = "",
        messages: Optional[list[ChatMessage]] = None,
        max_tokens: int = 512,
        temperature: float = 0.7,
        top_p: float = 1.0,
        stream: bool = False,
    ) -> GenerateResult | Iterator[str]:
        """
        Generate text using the host GPU.

        Args:
            prompt: Text prompt (for simple completion)
            model: Model ID to use
            messages: Chat messages (alternative to prompt)
            max_tokens: Maximum tokens to generate
            temperature: Sampling temperature
            top_p: Top-p sampling
            stream: If True, return iterator of tokens

        Returns:
            GenerateResult with full text, or iterator of tokens if stream=True
        """
        chat_messages = []
        if messages:
            chat_messages = [
                pb2.ChatMessage(role=m.role, content=m.content)
                for m in messages
            ]

        request = pb2.GenerateRequest(
            model_id=model,
            prompt=prompt,
            messages=chat_messages,
            parameters=pb2.GenerateParameters(
                max_tokens=max_tokens,
                temperature=temperature,
                top_p=top_p,
            ),
        )

        response_stream = self.stub.Generate(request)

        if stream:
            return self._stream_tokens(response_stream)
        else:
            return self._collect_response(response_stream)

    def _stream_tokens(self, response_stream) -> Iterator[str]:
        """Yield individual tokens from the stream."""
        for response in response_stream:
            if response.HasField("token"):
                yield response.token

    def _collect_response(self, response_stream) -> GenerateResult:
        """Collect all tokens and return a complete result."""
        full_text = ""
        result = GenerateResult(text="")

        for response in response_stream:
            if response.HasField("token"):
                full_text += response.token
            elif response.HasField("complete"):
                c = response.complete
                result = GenerateResult(
                    text=c.full_text or full_text,
                    prompt_tokens=c.prompt_tokens,
                    completion_tokens=c.completion_tokens,
                    prompt_time_seconds=c.prompt_time_seconds,
                    generation_time_seconds=c.generation_time_seconds,
                    tokens_per_second=c.tokens_per_second,
                )

        if not result.text:
            result.text = full_text

        return result

    # ── Health ────────────────────────────────────────────────────

    def get_gpu_status(self) -> GPUStatus:
        """Get GPU status from the daemon."""
        response = self.stub.GetGPUStatus(pb2.GetGPUStatusRequest())
        return GPUStatus(
            device_name=response.device_name,
            total_memory_bytes=response.total_memory_bytes,
            used_memory_bytes=response.used_memory_bytes,
            available_memory_bytes=response.available_memory_bytes,
            gpu_family=response.gpu_family,
            loaded_models_count=response.loaded_models_count,
            loaded_models=[
                ModelInfo(
                    model_id=m.model_id,
                    is_loaded=m.is_loaded,
                    model_type=m.model_type,
                )
                for m in response.loaded_models
            ],
        )

    def ping(self) -> dict:
        """Ping the daemon."""
        response = self.stub.Ping(pb2.PingRequest())
        return {
            "status": response.status,
            "version": response.version,
            "uptime_seconds": response.uptime_seconds,
        }


# Global client instance
_default_client: Optional[MLXContainerClient] = None


def get_client() -> MLXContainerClient:
    """Get or create the default client instance."""
    global _default_client
    if _default_client is None:
        _default_client = MLXContainerClient()
    return _default_client
