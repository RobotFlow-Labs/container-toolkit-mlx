"""Tests for mlx_container._vsock — vsock availability and target resolution."""

from __future__ import annotations

import os
import socket
from unittest.mock import patch, MagicMock

import pytest

from mlx_container._vsock import (
    _vsock_available,
    get_vsock_target,
    AF_VSOCK,
    VMADDR_CID_HOST,
    DEFAULT_PORT,
)


# ---------------------------------------------------------------------------
# _vsock_available()
# ---------------------------------------------------------------------------


class TestVsockAvailable:
    def test_returns_bool(self):
        result = _vsock_available()
        assert isinstance(result, bool)

    def test_returns_false_when_socket_raises_attribute_error(self):
        with patch("mlx_container._vsock.socket.socket", side_effect=AttributeError("no AF_VSOCK")):
            assert _vsock_available() is False

    def test_returns_false_when_socket_raises_os_error(self):
        with patch("mlx_container._vsock.socket.socket", side_effect=OSError("not supported")):
            assert _vsock_available() is False

    def test_returns_true_when_socket_creation_succeeds(self):
        mock_sock = MagicMock()
        with patch("mlx_container._vsock.socket.socket", return_value=mock_sock):
            result = _vsock_available()
        assert result is True
        mock_sock.close.assert_called_once()

    def test_macOS_returns_false_because_af_vsock_is_linux_only(self):
        # On macOS, AF_VSOCK (40) is a Linux-specific constant.
        # The function should return False since socket creation will fail.
        # This test verifies the actual runtime behavior on the test machine.
        result = _vsock_available()
        # On macOS the constant 40 is not AF_VSOCK so socket creation fails
        assert result is False


# ---------------------------------------------------------------------------
# get_vsock_target()
# ---------------------------------------------------------------------------


class TestGetVsockTarget:
    def test_returns_string(self):
        result = get_vsock_target()
        assert isinstance(result, str)

    def test_returns_non_empty_string(self):
        result = get_vsock_target()
        assert len(result) > 0

    def test_falls_back_to_tcp_when_vsock_unavailable(self):
        with patch("mlx_container._vsock._vsock_available", return_value=False):
            target = get_vsock_target()
        # Should be a TCP target, not a vsock URI
        assert not target.startswith("vsock:")

    def test_fallback_tcp_target_contains_localhost_by_default(self):
        with patch("mlx_container._vsock._vsock_available", return_value=False):
            # Ensure env vars are cleared for determinism
            env_overrides = {k: None for k in ("MLX_DAEMON_HOST", "MLX_DAEMON_PORT")}
            with patch.dict(os.environ, {k: v for k, v in env_overrides.items() if v}, clear=False):
                # Remove keys rather than setting to None
                for k in ("MLX_DAEMON_HOST", "MLX_DAEMON_PORT"):
                    os.environ.pop(k, None)
                target = get_vsock_target()
        assert "localhost" in target

    def test_fallback_tcp_respects_mlx_daemon_host_env_var(self):
        with patch("mlx_container._vsock._vsock_available", return_value=False):
            with patch.dict(os.environ, {"MLX_DAEMON_HOST": "192.168.1.100", "MLX_DAEMON_PORT": "9999"}):
                target = get_vsock_target()
        assert "192.168.1.100" in target
        assert "9999" in target

    def test_fallback_tcp_respects_mlx_daemon_port_env_var(self):
        with patch("mlx_container._vsock._vsock_available", return_value=False):
            with patch.dict(os.environ, {"MLX_DAEMON_PORT": "12345"}):
                os.environ.pop("MLX_DAEMON_HOST", None)
                target = get_vsock_target()
        assert "12345" in target

    def test_returns_vsock_uri_when_vsock_available(self):
        with patch("mlx_container._vsock._vsock_available", return_value=True):
            # Clean env so defaults are used
            for k in ("MLX_VSOCK_CID", "MLX_VSOCK_PORT"):
                os.environ.pop(k, None)
            target = get_vsock_target()
        assert target.startswith("vsock:")

    def test_vsock_uri_contains_default_cid_and_port(self):
        with patch("mlx_container._vsock._vsock_available", return_value=True):
            for k in ("MLX_VSOCK_CID", "MLX_VSOCK_PORT"):
                os.environ.pop(k, None)
            target = get_vsock_target()
        # Default: vsock:2:2048
        assert f"vsock:{VMADDR_CID_HOST}:{DEFAULT_PORT}" == target

    def test_vsock_uri_respects_mlx_vsock_port_env_var(self):
        with patch("mlx_container._vsock._vsock_available", return_value=True):
            with patch.dict(os.environ, {"MLX_VSOCK_PORT": "3000"}):
                os.environ.pop("MLX_VSOCK_CID", None)
                target = get_vsock_target()
        assert target == f"vsock:{VMADDR_CID_HOST}:3000"

    def test_vsock_uri_respects_mlx_vsock_cid_env_var(self):
        with patch("mlx_container._vsock._vsock_available", return_value=True):
            with patch.dict(os.environ, {"MLX_VSOCK_CID": "5"}):
                os.environ.pop("MLX_VSOCK_PORT", None)
                target = get_vsock_target()
        assert target == f"vsock:5:{DEFAULT_PORT}"


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------


class TestVsockConstants:
    def test_af_vsock_value(self):
        assert AF_VSOCK == 40

    def test_vmaddr_cid_host_value(self):
        assert VMADDR_CID_HOST == 2

    def test_default_port_value(self):
        assert DEFAULT_PORT == 2048
