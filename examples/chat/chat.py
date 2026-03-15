#!/usr/bin/env python3
"""
Interactive terminal chat with an MLX model.

Connects to the MLX Container Daemon via vsock (inside a container)
or TCP (local dev mode) and maintains a multi-turn conversation.

Usage:
    # Inside a container (vsock auto-detected):
    python3 chat.py --model mlx-community/Llama-3.2-1B-4bit

    # Local dev mode:
    python3 chat.py --host localhost --port 50051 --model mlx-community/Llama-3.2-1B-4bit

    # With a custom system prompt:
    python3 chat.py --system "You are a concise assistant. Answer in one sentence."

Controls:
    Ctrl+C or Ctrl+D  — exit
    /quit             — exit
    /clear            — clear conversation history
    /stats            — show last response statistics
    /models           — list loaded models
"""

from __future__ import annotations

import argparse
import os
import sys
import time
from typing import NoReturn

# ---------------------------------------------------------------------------
# ANSI colour helpers — fall back gracefully on non-TTY / Windows terminals
# ---------------------------------------------------------------------------

_USE_COLOUR = sys.stdout.isatty() and os.environ.get("NO_COLOR") is None


def _c(code: str, text: str) -> str:
    """Wrap *text* in an ANSI escape sequence when colour is enabled."""
    if not _USE_COLOUR:
        return text
    return f"\033[{code}m{text}\033[0m"


def _user(text: str) -> str:
    return _c("1;36", text)          # bold cyan


def _assistant(text: str) -> str:
    return _c("32", text)            # green


def _system_msg(text: str) -> str:
    return _c("2;33", text)          # dim yellow


def _info(text: str) -> str:
    return _c("2;37", text)          # dim white


def _error(text: str) -> str:
    return _c("1;31", text)          # bold red


def _stat(text: str) -> str:
    return _c("35", text)            # magenta


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

DEFAULT_MODEL = "mlx-community/Llama-3.2-1B-4bit"
DEFAULT_SYSTEM = "You are a helpful, accurate, and concise assistant."


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Interactive chat with an MLX model via the MLX Container Toolkit",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "--model",
        default=DEFAULT_MODEL,
        help="HuggingFace model ID to chat with",
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
        "--system",
        default=DEFAULT_SYSTEM,
        help="System prompt for the conversation",
    )
    parser.add_argument(
        "--max-tokens",
        type=int,
        default=512,
        help="Maximum tokens per response",
    )
    parser.add_argument(
        "--temperature",
        type=float,
        default=0.7,
        help="Sampling temperature",
    )
    return parser.parse_args()


# ---------------------------------------------------------------------------
# Transport
# ---------------------------------------------------------------------------

def _configure_transport(host: str | None, port: int | None) -> None:
    if host is not None:
        os.environ["MLX_DAEMON_HOST"] = host
    if port is not None:
        os.environ["MLX_DAEMON_PORT"] = str(port)


# ---------------------------------------------------------------------------
# Chat session
# ---------------------------------------------------------------------------

class LastStats:
    """Holds statistics from the most recent response."""

    tokens_per_second: float = 0.0
    prompt_tokens: int = 0
    completion_tokens: int = 0
    prompt_time: float = 0.0
    gen_time: float = 0.0


_last_stats = LastStats()


def _chat_turn(
    model: str,
    history: list[dict],
    max_tokens: int,
    temperature: float,
) -> str:
    """
    Stream one assistant turn, printing tokens as they arrive.

    Returns the full assembled response text.
    """
    from mlx_container import generate
    from mlx_container.types import ChatMessage

    messages = [ChatMessage(role=m["role"], content=m["content"]) for m in history]

    print(_assistant("Assistant: "), end="", flush=True)

    tokens: list[str] = []
    t_start = time.perf_counter()

    for token in generate(
        model=model,
        messages=messages,
        max_tokens=max_tokens,
        temperature=temperature,
        stream=True,
    ):
        print(_assistant(token), end="", flush=True)
        tokens.append(token)

    elapsed = time.perf_counter() - t_start
    full_text = "".join(tokens)

    # Update stats (approximate — server does not expose per-stream stats)
    _last_stats.completion_tokens = len(tokens)
    _last_stats.gen_time = elapsed
    _last_stats.tokens_per_second = len(tokens) / elapsed if elapsed > 0 else 0.0

    print()  # newline after streamed response
    return full_text


def _print_stats() -> None:
    if _last_stats.completion_tokens == 0:
        print(_info("  No response yet."))
        return
    print(_stat(
        f"  Completion tokens : {_last_stats.completion_tokens}\n"
        f"  Generation time   : {_last_stats.gen_time:.2f}s\n"
        f"  Tokens/sec        : {_last_stats.tokens_per_second:.1f}"
    ))


def _print_models() -> None:
    from mlx_container import list_models
    try:
        models = list_models()
        if not models:
            print(_info("  No models loaded."))
            return
        for m in models:
            mem_mb = m.memory_used_bytes / 1024 / 1024
            flag = "loaded" if m.is_loaded else "unloaded"
            print(_info(f"  {m.model_id}  [{flag}, {mem_mb:.0f} MB]"))
    except Exception as exc:
        print(_error(f"  Could not list models: {exc}"))


def _repl(
    model: str,
    system_prompt: str,
    max_tokens: int,
    temperature: float,
) -> None:
    """Run the interactive chat REPL until the user exits."""
    history: list[dict] = [{"role": "system", "content": system_prompt}]

    print()
    print(_info("=" * 60))
    print(_info("  MLX Container — Interactive Chat"))
    print(_info(f"  Model       : {model}"))
    print(_info(f"  System      : {system_prompt[:60]}{'...' if len(system_prompt) > 60 else ''}"))
    print(_info("  Commands    : /quit  /clear  /stats  /models"))
    print(_info("  Exit        : Ctrl+C or Ctrl+D"))
    print(_info("=" * 60))
    print()

    while True:
        # Read user input
        try:
            user_input = input(_user("You: ")).strip()
        except (EOFError, KeyboardInterrupt):
            print(_info("\nBye!"))
            break

        if not user_input:
            continue

        # Built-in commands
        if user_input.lower() in ("/quit", "/exit", "/q"):
            print(_info("Bye!"))
            break
        if user_input.lower() in ("/clear", "/reset"):
            history = [{"role": "system", "content": system_prompt}]
            print(_info("  Conversation cleared."))
            continue
        if user_input.lower() == "/stats":
            _print_stats()
            continue
        if user_input.lower() == "/models":
            _print_models()
            continue

        # Normal chat turn
        history.append({"role": "user", "content": user_input})
        try:
            response = _chat_turn(model, history, max_tokens, temperature)
        except KeyboardInterrupt:
            print(_info("\n  (response interrupted)"))
            response = ""
        except Exception as exc:
            print(_error(f"\n  Error during generation: {exc}"))
            # Pop the user message we just added so the history stays consistent
            history.pop()
            continue

        # Append assistant turn only if we got a real response
        if response:
            history.append({"role": "assistant", "content": response})

        # Show brief token/s stat after each response
        if _last_stats.tokens_per_second > 0:
            print(
                _info(
                    f"  [{_last_stats.completion_tokens} tokens, "
                    f"{_last_stats.tokens_per_second:.1f} tok/s]"
                )
            )
        print()


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    args = _parse_args()
    _configure_transport(args.host, args.port)

    # Validate client import before entering the REPL
    try:
        from mlx_container._grpc_client import get_client  # noqa: F401
    except ImportError as exc:
        print(_error(f"mlx_container not found: {exc}"), file=sys.stderr)
        print(_error("Install with: pip install -e client/"), file=sys.stderr)
        sys.exit(1)

    # Verify daemon connectivity up front for a clean error message
    try:
        from mlx_container._grpc_client import get_client
        get_client().ping()
    except Exception as exc:
        print(
            _error(
                f"\nCannot reach MLX Container Daemon: {exc}\n\n"
                "Checklist:\n"
                "  - Inside a container: was --gpu passed to `container run`?\n"
                "  - Local dev mode    : is mlx-container-daemon running?\n"
                "  - TCP override      : pass --host/--port or set env vars"
            ),
            file=sys.stderr,
        )
        sys.exit(1)

    _repl(
        model=args.model,
        system_prompt=args.system,
        max_tokens=args.max_tokens,
        temperature=args.temperature,
    )


if __name__ == "__main__":
    main()
