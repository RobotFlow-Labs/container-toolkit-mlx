#!/usr/bin/env python3
"""
Embedding similarity example for MLX Container Toolkit.

Requests embedding vectors from the MLX Container Daemon, then computes
pairwise cosine similarities between every input text.  Results are
pretty-printed as a ranked similarity matrix.

Usage:
    # Compare strings from the CLI:
    python3 embed.py "Apple Silicon is fast" "M3 chip performance" "Python is great"

    # Read texts from stdin (one per line):
    echo -e "quantum computing\\nmachine learning\\ncooking pasta" | python3 embed.py

    # Custom model and connection:
    python3 embed.py --model mlx-community/nomic-embed-text-v1 \\
        --host localhost --port 50051 \\
        "text one" "text two"

    # Output raw JSON (useful for piping):
    python3 embed.py --json "hello world" "goodbye world"

Note:
    Embedding support requires a daemon version that exposes the Embed RPC.
    If the daemon does not support embeddings, a clear error is shown with a
    workaround suggestion.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import sys
from typing import Sequence


# ---------------------------------------------------------------------------
# ANSI helpers
# ---------------------------------------------------------------------------

_USE_COLOUR = sys.stdout.isatty() and os.environ.get("NO_COLOR") is None


def _c(code: str, text: str) -> str:
    return f"\033[{code}m{text}\033[0m" if _USE_COLOUR else text


def _bold(t: str) -> str:
    return _c("1", t)


def _dim(t: str) -> str:
    return _c("2", t)


def _green(t: str) -> str:
    return _c("32", t)


def _yellow(t: str) -> str:
    return _c("33", t)


def _red(t: str) -> str:
    return _c("31", t)


# ---------------------------------------------------------------------------
# Cosine similarity
# ---------------------------------------------------------------------------

def cosine_similarity(a: Sequence[float], b: Sequence[float]) -> float:
    """Compute the cosine similarity between two vectors."""
    dot = sum(x * y for x, y in zip(a, b))
    norm_a = math.sqrt(sum(x * x for x in a))
    norm_b = math.sqrt(sum(y * y for y in b))
    if norm_a == 0.0 or norm_b == 0.0:
        return 0.0
    return dot / (norm_a * norm_b)


def _similarity_colour(score: float) -> str:
    """Return a colourised string for a similarity score."""
    text = f"{score:.4f}"
    if score >= 0.85:
        return _green(text)
    if score >= 0.60:
        return _yellow(text)
    return _red(text)


# ---------------------------------------------------------------------------
# Embedding via the MLX Container client
# ---------------------------------------------------------------------------

def _get_embeddings(
    texts: list[str],
    model: str,
) -> list[list[float]]:
    """
    Request embeddings from the daemon.

    The MLX Container gRPC service exposes an Embed RPC that accepts a list
    of strings and returns float32 vectors.  If the installed daemon version
    does not yet support embeddings, a ``NotImplementedError`` is raised with
    a helpful message.
    """
    from mlx_container._grpc_client import get_client
    from mlx_container.proto import mlx_container_pb2 as pb2

    client = get_client()
    client._ensure_connected()

    # Build the embed request.  The proto field is `texts` (repeated string)
    # and `model_id` (string).
    try:
        request = pb2.EmbedRequest(model_id=model, texts=texts)
        response = client.stub.Embed(request)
    except AttributeError:
        raise NotImplementedError(
            "The EmbedRequest proto is not available in this version of the\n"
            "generated stubs.  Run `make proto` in the repo root to regenerate,\n"
            "or upgrade the mlx-container-daemon to a version that includes the\n"
            "Embed RPC."
        )
    except Exception as exc:
        # grpc.RpcError surfaces as a generic exception; extract the message.
        msg = str(exc)
        if "UNIMPLEMENTED" in msg.upper():
            raise NotImplementedError(
                "The connected daemon does not implement the Embed RPC yet.\n"
                "Upgrade the daemon or use a model server that exposes embeddings."
            )
        raise RuntimeError(f"Embed RPC failed: {exc}") from exc

    # response.embeddings is a repeated EmbeddingVector, each with a `values`
    # field containing the float32 components.
    return [list(ev.values) for ev in response.embeddings]


# ---------------------------------------------------------------------------
# Output formatters
# ---------------------------------------------------------------------------

def _print_matrix(texts: list[str], sims: list[list[float]]) -> None:
    """Print a full pairwise similarity matrix."""
    n = len(texts)
    col_w = 8

    # Header
    print(_bold("\nPairwise Cosine Similarity Matrix"))
    print(_dim("-" * (20 + col_w * n)))

    # Column labels (truncated to col_w - 1 chars)
    header = " " * 22
    for j in range(n):
        label = f"[{j}]"
        header += label.center(col_w)
    print(_dim(header))

    for i in range(n):
        label = f"[{i}] {texts[i][:18]:<18}"
        row = _bold(label)
        for j in range(n):
            row += _similarity_colour(sims[i][j]).center(col_w + 10)  # extra for ANSI chars
        print(row)

    print()

    # Ranked pairs
    pairs = []
    for i in range(n):
        for j in range(i + 1, n):
            pairs.append((sims[i][j], i, j))
    pairs.sort(reverse=True)

    print(_bold("Ranked Pairs (most similar first)"))
    print(_dim("-" * 60))
    for rank, (score, i, j) in enumerate(pairs, start=1):
        bar_len = int(score * 30)
        bar = "#" * bar_len + "-" * (30 - bar_len)
        print(
            f"  {rank:>2}. {_similarity_colour(score)}  [{bar}]"
            f"  {_dim(repr(texts[i][:30]))}  vs  {_dim(repr(texts[j][:30]))}"
        )
    print()


def _print_json(
    texts: list[str],
    embeddings: list[list[float]],
    sims: list[list[float]],
) -> None:
    n = len(texts)
    pairs = []
    for i in range(n):
        for j in range(i + 1, n):
            pairs.append({"i": i, "j": j, "text_i": texts[i], "text_j": texts[j], "similarity": sims[i][j]})
    pairs.sort(key=lambda p: p["similarity"], reverse=True)

    output = {
        "texts": texts,
        "embedding_dim": len(embeddings[0]) if embeddings else 0,
        "similarities": [[sims[i][j] for j in range(n)] for i in range(n)],
        "ranked_pairs": pairs,
    }
    print(json.dumps(output, indent=2))


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Compute and compare text embeddings via the MLX Container Toolkit",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "texts",
        nargs="*",
        help=(
            "Texts to embed.  When omitted, lines are read from stdin. "
            "At least two texts are required for similarity comparison."
        ),
    )
    parser.add_argument(
        "--model",
        default="mlx-community/nomic-embed-text-v1",
        help="Embedding model ID to use",
    )
    parser.add_argument(
        "--host",
        default=None,
        help="Daemon TCP host for local dev mode",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=None,
        help="Daemon TCP port for local dev mode",
    )
    parser.add_argument(
        "--json",
        dest="as_json",
        action="store_true",
        help="Output raw JSON instead of pretty-printed table",
    )
    return parser.parse_args()


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    args = _parse_args()

    # Configure transport
    if args.host is not None:
        os.environ["MLX_DAEMON_HOST"] = args.host
    if args.port is not None:
        os.environ["MLX_DAEMON_PORT"] = str(args.port)

    # Collect texts
    texts: list[str] = list(args.texts)
    if not texts:
        if sys.stdin.isatty():
            print("Enter texts to embed (one per line, blank line to finish):")
        for line in sys.stdin:
            stripped = line.rstrip("\n")
            if stripped:
                texts.append(stripped)

    if len(texts) < 2:
        print(
            "At least two texts are required for similarity comparison.",
            file=sys.stderr,
        )
        sys.exit(1)

    # Verify client is importable
    try:
        from mlx_container._grpc_client import get_client  # noqa: F401
    except ImportError as exc:
        print(f"mlx_container not found: {exc}", file=sys.stderr)
        print("Install with: pip install -e client/", file=sys.stderr)
        sys.exit(1)

    if not args.as_json:
        print(f"\nEmbedding {len(texts)} text(s) using model: {_bold(args.model)}")

    try:
        embeddings = _get_embeddings(texts, model=args.model)
    except NotImplementedError as exc:
        print(f"\n[NOT IMPLEMENTED] {exc}", file=sys.stderr)
        sys.exit(2)
    except RuntimeError as exc:
        print(f"\n[ERROR] {exc}", file=sys.stderr)
        sys.exit(1)

    if not args.as_json:
        dim = len(embeddings[0]) if embeddings else 0
        print(f"Embedding dimension: {dim}\n")

    # Build pairwise similarity matrix
    n = len(texts)
    sims = [[0.0] * n for _ in range(n)]
    for i in range(n):
        for j in range(n):
            sims[i][j] = cosine_similarity(embeddings[i], embeddings[j])

    if args.as_json:
        _print_json(texts, embeddings, sims)
    else:
        _print_matrix(texts, sims)


if __name__ == "__main__":
    main()
