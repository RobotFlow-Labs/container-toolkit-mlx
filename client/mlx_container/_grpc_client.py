"""
gRPC client for communicating with the MLX Container Daemon.

Supports both vsock (in containers) and TCP (for development).

Transport selection:
  - Inside a Linux container: vsock CID 2, port 2048 (host daemon).
  - Development / outside container: TCP, defaults to localhost:50051.
    Override with env vars MLX_DAEMON_HOST / MLX_DAEMON_PORT.

The Swift gRPC server uses JSON serialisation (not binary protobuf).
See mlx_container/proto/ for the matching Python stubs.
"""

from __future__ import annotations

import os
import socket
import threading
from typing import Iterator, Optional

import grpc

from mlx_container._vsock import get_vsock_target, _vsock_available, DEFAULT_PORT, VMADDR_CID_HOST
from mlx_container.types import GenerateResult, ModelInfo, GPUStatus, ChatMessage
from mlx_container.proto import mlx_container_pb2 as pb2
from mlx_container.proto import mlx_container_pb2_grpc as pb2_grpc


# ---------------------------------------------------------------------------
# vsock channel factory
# ---------------------------------------------------------------------------

def _make_vsock_channel(cid: int, port: int) -> grpc.Channel:
    """
    Build a gRPC channel that connects via AF_VSOCK.

    grpcio does not have native vsock support, so we wrap the vsock socket
    in a local TCP proxy using a ``grpc.local_channel_credentials``-style
    approach: we create the vsock socket ourselves and hand it to gRPC via
    a custom channel target using the ``grpc.experimental`` socket factory
    API.  As a pragmatic fallback that works with stock grpcio, we instead
    bind a local loopback TCP port, connect it to the vsock peer, and hand
    gRPC a normal TCP target.  This is the simplest approach that requires
    no C extensions beyond grpcio itself.
    """
    # Pick a free ephemeral TCP port on loopback.
    listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    listener.bind(("127.0.0.1", 0))
    tcp_port = listener.getsockname()[1]
    listener.listen(5)

    # Synchronisation: the proxy thread signals whether the first vsock
    # connect succeeded so the calling thread can fail fast instead of
    # returning a channel that will never work.
    _ready = threading.Event()
    _error: list[Exception] = []  # at most one element; list is thread-safe for append

    def _forward(src: socket.socket, dst: socket.socket) -> None:
        try:
            while True:
                chunk = src.recv(65536)
                if not chunk:
                    break
                dst.sendall(chunk)
        except OSError:
            pass
        finally:
            src.close()
            dst.close()

    def _bridge(tcp_conn: socket.socket) -> None:
        """Connect one accepted TCP socket to vsock and start forwarding."""
        AF_VSOCK: int = 40  # Linux AF_VSOCK constant
        try:
            vs_sock = socket.socket(AF_VSOCK, socket.SOCK_STREAM)
            vs_sock.connect((cid, port))
        except OSError as exc:
            tcp_conn.close()
            raise ConnectionError(
                f"vsock connect failed (CID={cid}, port={port}): {exc}"
            ) from exc
        threading.Thread(target=_forward, args=(tcp_conn, vs_sock), daemon=True).start()
        threading.Thread(target=_forward, args=(vs_sock, tcp_conn), daemon=True).start()

    def _proxy() -> None:
        """
        Accept TCP connections from gRPC and bridge each one to vsock.

        The listener stays open so that gRPC reconnect attempts (after a
        transient failure or idle-timeout) are handled correctly.  A
        threading.Event is used to surface the result of the *first* vsock
        connect attempt back to the calling thread.
        """
        first = True
        while True:
            try:
                tcp_conn, _ = listener.accept()
            except OSError:
                # Listener was closed (e.g. client called close()), exit loop.
                return
            try:
                _bridge(tcp_conn)
                if first:
                    first = False
                    _ready.set()
            except ConnectionError as exc:
                if first:
                    first = False
                    _error.append(exc)
                    _ready.set()
                # For subsequent reconnects, the gRPC layer will surface the
                # failure through its own retry/backoff machinery.

    threading.Thread(target=_proxy, daemon=True).start()

    # Block until the first vsock connection attempt completes (or times out).
    # A 5-second timeout is generous for a loopback + vsock connect; if it
    # expires we let gRPC proceed and surface errors through normal RPC status.
    _ready.wait(timeout=5.0)
    if _error:
        listener.close()
        raise _error[0]

    return grpc.insecure_channel(f"127.0.0.1:{tcp_port}")


# ---------------------------------------------------------------------------
# Client
# ---------------------------------------------------------------------------

class MLXContainerClient:
    """
    Client for the MLX Container Daemon.

    Connects over vsock when running inside an Apple container VM, or TCP
    for local development.

    Args:
        target: Explicit gRPC target string (e.g. ``"localhost:50051"`` or
                ``"vsock:2:2048"``).  When omitted, auto-detected from
                environment.
        vsock_cid: vsock context ID (default 2 = host).  Only used when
                   ``target`` is omitted and vsock is available.
        vsock_port: vsock port (default 2048).  Only used as above.
    """

    def __init__(
        self,
        target: Optional[str] = None,
        vsock_cid: int = VMADDR_CID_HOST,
        vsock_port: int = DEFAULT_PORT,
    ) -> None:
        if target:
            self._target = target
        else:
            self._target = get_vsock_target()

        self._vsock_cid = vsock_cid
        self._vsock_port = vsock_port
        self._channel: Optional[grpc.Channel] = None
        self._stub: Optional[pb2_grpc.MLXContainerServiceStub] = None

    # ------------------------------------------------------------------
    # Connection lifecycle
    # ------------------------------------------------------------------

    def _ensure_connected(self) -> None:
        """Lazily establish gRPC connection."""
        if self._channel is not None:
            return

        if self._target.startswith("vsock:"):
            parts = self._target.split(":")
            cid = int(parts[1])
            port = int(parts[2])
            self._channel = _make_vsock_channel(cid, port)
        else:
            self._channel = grpc.insecure_channel(self._target)

        self._stub = pb2_grpc.MLXContainerServiceStub(self._channel)

    @property
    def stub(self) -> pb2_grpc.MLXContainerServiceStub:
        self._ensure_connected()
        assert self._stub is not None
        return self._stub

    def close(self) -> None:
        """Close the gRPC channel."""
        if self._channel:
            self._channel.close()
            self._channel = None
            self._stub = None

    def __enter__(self) -> "MLXContainerClient":
        return self

    def __exit__(self, *args: object) -> None:
        self.close()

    # ------------------------------------------------------------------
    # Model management
    # ------------------------------------------------------------------

    def load_model(
        self,
        model_id: str,
        alias: str = "",
        memory_budget_bytes: int = 0,
    ) -> bool:
        """Load a model on the host GPU."""
        request = pb2.LoadModelRequest(
            model_id=model_id,
            alias=alias,
            memory_budget_bytes=memory_budget_bytes,
        )
        response: pb2.LoadModelResponse = self.stub.LoadModel(request)
        if not response.success:
            raise RuntimeError(f"Failed to load model '{model_id}': {response.error}")
        return True

    def unload_model(self, model_id: str) -> bool:
        """Unload a model from the host GPU."""
        request = pb2.UnloadModelRequest(model_id=model_id)
        response: pb2.UnloadModelResponse = self.stub.UnloadModel(request)
        if not response.success:
            raise RuntimeError(f"Failed to unload model '{model_id}': {response.error}")
        return True

    def list_models(self) -> list[ModelInfo]:
        """List all loaded models."""
        response: pb2.ListModelsResponse = self.stub.ListModels(pb2.ListModelsRequest())
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

    # ------------------------------------------------------------------
    # Inference
    # ------------------------------------------------------------------

    def generate(
        self,
        prompt: str = "",
        model: str = "",
        messages: Optional[list[ChatMessage]] = None,
        max_tokens: int = 512,
        temperature: float = 0.7,
        top_p: float = 1.0,
        stream: bool = False,
    ) -> "GenerateResult | Iterator[str]":
        """
        Generate text using the host GPU.

        Args:
            prompt: Text prompt (for simple completion).
            model: Model ID to use.
            messages: Chat messages (alternative to prompt).
            max_tokens: Maximum tokens to generate.
            temperature: Sampling temperature.
            top_p: Top-p sampling.
            stream: If True, return an iterator yielding token strings.

        Returns:
            ``GenerateResult`` with full text and stats, or a token
            iterator when ``stream=True``.
        """
        pb_messages = [
            pb2.ChatMessage(role=m.role, content=m.content)
            for m in (messages or [])
        ]

        request = pb2.GenerateRequest(
            model_id=model,
            prompt=prompt,
            messages=pb_messages,
            parameters=pb2.GenerateParameters(
                max_tokens=max_tokens,
                temperature=temperature,
                top_p=top_p,
            ),
        )

        response_stream = self.stub.Generate(request)

        if stream:
            return self._stream_tokens(response_stream)
        return self._collect_response(response_stream)

    def _stream_tokens(self, response_stream) -> Iterator[str]:
        """Yield individual token strings from the server-streaming response."""
        for response in response_stream:
            # The Swift server sets either ``token`` (str) or ``complete``
            # (GenerateComplete).  We only yield non-None tokens here.
            if response.HasField("token"):
                yield response.token  # type: ignore[misc]

    def _collect_response(self, response_stream) -> GenerateResult:
        """Collect all streamed frames and return a single GenerateResult."""
        tokens: list[str] = []
        final: Optional[pb2.GenerateComplete] = None

        for response in response_stream:
            if response.HasField("token"):
                tokens.append(response.token)  # type: ignore[arg-type]
            elif response.HasField("complete"):
                final = response.complete

        if final is not None:
            return GenerateResult(
                text=final.full_text if final.full_text else "".join(tokens),
                prompt_tokens=final.prompt_tokens,
                completion_tokens=final.completion_tokens,
                prompt_time_seconds=final.prompt_time_seconds,
                generation_time_seconds=final.generation_time_seconds,
                tokens_per_second=final.tokens_per_second,
            )

        # No ``complete`` frame received — return accumulated tokens.
        return GenerateResult(text="".join(tokens))

    # ------------------------------------------------------------------
    # Health
    # ------------------------------------------------------------------

    def get_gpu_status(self) -> GPUStatus:
        """Get GPU status from the daemon."""
        response: pb2.GetGPUStatusResponse = self.stub.GetGPUStatus(
            pb2.GetGPUStatusRequest()
        )
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
                    alias=m.alias,
                    memory_used_bytes=m.memory_used_bytes,
                    is_loaded=m.is_loaded,
                    model_type=m.model_type,
                )
                for m in response.loaded_models
            ],
        )

    def ping(self) -> dict:
        """Ping the daemon and return a status dict."""
        response: pb2.PingResponse = self.stub.Ping(pb2.PingRequest())
        return {
            "status": response.status,
            "version": response.version,
            "uptime_seconds": response.uptime_seconds,
        }


# ---------------------------------------------------------------------------
# Module-level default client
# ---------------------------------------------------------------------------

_default_client: Optional[MLXContainerClient] = None


def get_client() -> MLXContainerClient:
    """Get or create the process-wide default client instance."""
    global _default_client
    if _default_client is None:
        _default_client = MLXContainerClient()
    return _default_client
