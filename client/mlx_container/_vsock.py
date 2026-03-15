"""
AF_VSOCK connection to the host GPU daemon.

vsock is the communication channel between the Linux VM (guest) and macOS (host).
This is the same channel that Apple's vminitd uses.

CID 2 = host, port 2048 = default daemon port.
"""

import socket
import os
from typing import Optional

# vsock constants
AF_VSOCK = 40  # Linux AF_VSOCK address family
VMADDR_CID_HOST = 2  # CID for the hypervisor host
DEFAULT_PORT = 2048


def create_vsock_connection(
    cid: int = VMADDR_CID_HOST,
    port: int = DEFAULT_PORT,
    timeout: Optional[float] = 30.0,
) -> socket.socket:
    """
    Create a vsock connection to the host daemon.

    Args:
        cid: Context ID (2 = host)
        port: vsock port number
        timeout: Connection timeout in seconds

    Returns:
        Connected socket

    Raises:
        ConnectionError: If vsock is not available or connection fails
    """
    try:
        sock = socket.socket(AF_VSOCK, socket.SOCK_STREAM)
    except (AttributeError, OSError) as e:
        raise ConnectionError(
            f"AF_VSOCK not available. Are you running inside a Linux container? "
            f"Error: {e}"
        ) from e

    if timeout is not None:
        sock.settimeout(timeout)

    try:
        sock.connect((cid, port))
    except OSError as e:
        sock.close()
        raise ConnectionError(
            f"Failed to connect to host daemon via vsock (CID={cid}, port={port}). "
            f"Is mlx-container-daemon running on the host? Error: {e}"
        ) from e

    return sock


def get_vsock_target() -> str:
    """
    Get the gRPC target string for vsock connection.

    Returns a vsock URI that gRPC can connect to.
    Falls back to localhost for development/testing outside containers.
    """
    cid = int(os.environ.get("MLX_VSOCK_CID", str(VMADDR_CID_HOST)))
    port = int(os.environ.get("MLX_VSOCK_PORT", str(DEFAULT_PORT)))

    # Check if we're in a container (vsock available)
    if _vsock_available():
        return f"vsock:{cid}:{port}"

    # Fallback to TCP for development
    host = os.environ.get("MLX_DAEMON_HOST", "localhost")
    tcp_port = os.environ.get("MLX_DAEMON_PORT", "50051")
    return f"{host}:{tcp_port}"


def _vsock_available() -> bool:
    """Check if AF_VSOCK is available on this system."""
    try:
        sock = socket.socket(AF_VSOCK, socket.SOCK_STREAM)
        sock.close()
        return True
    except (AttributeError, OSError):
        return False
