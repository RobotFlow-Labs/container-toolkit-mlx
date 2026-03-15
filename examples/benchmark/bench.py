#!/usr/bin/env python3
"""
Inference performance benchmark for the MLX Container Toolkit.

Runs N generation requests against the MLX Container Daemon and reports
aggregate latency and throughput statistics.

Usage:
    # Basic benchmark (10 iterations, default model):
    python3 bench.py

    # Custom configuration:
    python3 bench.py --model mlx-community/Llama-3.2-3B-4bit \\
        --iterations 20 \\
        --max-tokens 100 \\
        --prompt "Describe the Milky Way galaxy in detail."

    # Local dev mode with JSON output:
    python3 bench.py --host localhost --port 50051 --json

    # Vary prompt length to measure prompt-processing throughput:
    python3 bench.py --prompt-tokens 512 --max-tokens 1

Metrics reported:
    - Total requests, successes, failures
    - Tokens/sec: mean, p50, p95, p99, min, max
    - Time-to-first-token (TTFT): mean, p50, p95, p99
    - End-to-end latency: mean, p50, p95, p99
    - Total throughput (tokens generated per second across all requests)
"""

from __future__ import annotations

import argparse
import json
import math
import os
import sys
import time
from dataclasses import dataclass, field, asdict
from typing import Any


# ---------------------------------------------------------------------------
# Result containers
# ---------------------------------------------------------------------------

@dataclass
class RunResult:
    """Outcome of a single benchmark iteration."""

    iteration: int
    success: bool
    error: str = ""
    prompt_tokens: int = 0
    completion_tokens: int = 0
    prompt_time_seconds: float = 0.0
    generation_time_seconds: float = 0.0
    tokens_per_second: float = 0.0
    wall_time_seconds: float = 0.0  # end-to-end wall clock time


@dataclass
class BenchmarkStats:
    """Aggregate statistics over all successful runs."""

    model: str
    prompt: str
    max_tokens: int
    temperature: float
    total_iterations: int
    successful: int
    failed: int

    # Tokens/sec
    tps_mean: float = 0.0
    tps_p50: float = 0.0
    tps_p95: float = 0.0
    tps_p99: float = 0.0
    tps_min: float = 0.0
    tps_max: float = 0.0

    # End-to-end latency (wall clock)
    latency_mean_s: float = 0.0
    latency_p50_s: float = 0.0
    latency_p95_s: float = 0.0
    latency_p99_s: float = 0.0

    # Prompt processing time (TTFT proxy)
    ttft_mean_s: float = 0.0
    ttft_p50_s: float = 0.0
    ttft_p95_s: float = 0.0
    ttft_p99_s: float = 0.0

    # Aggregate
    total_tokens_generated: int = 0
    total_wall_time_s: float = 0.0
    aggregate_throughput_tps: float = 0.0

    errors: list[str] = field(default_factory=list)


# ---------------------------------------------------------------------------
# Statistics helpers
# ---------------------------------------------------------------------------

def _percentile(sorted_data: list[float], pct: float) -> float:
    """Compute the *pct*-th percentile of an already-sorted list."""
    if not sorted_data:
        return 0.0
    n = len(sorted_data)
    k = (n - 1) * pct / 100.0
    lo, hi = int(k), min(int(k) + 1, n - 1)
    frac = k - lo
    return sorted_data[lo] + frac * (sorted_data[hi] - sorted_data[lo])


def _compute_stats(values: list[float]) -> tuple[float, float, float, float, float, float]:
    """Return (mean, p50, p95, p99, min, max) for *values*."""
    if not values:
        return 0.0, 0.0, 0.0, 0.0, 0.0, 0.0
    sv = sorted(values)
    mean = sum(sv) / len(sv)
    return (
        mean,
        _percentile(sv, 50),
        _percentile(sv, 95),
        _percentile(sv, 99),
        sv[0],
        sv[-1],
    )


# ---------------------------------------------------------------------------
# Synthetic prompt builder
# ---------------------------------------------------------------------------

_FILLER_SENTENCE = (
    "The quick brown fox jumps over the lazy dog. "
    "Apple Silicon delivers exceptional performance for machine learning workloads. "
)


def _build_prompt(target_tokens: int | None, explicit_prompt: str | None) -> str:
    """
    Return a benchmark prompt.

    When *target_tokens* is given the prompt is padded to approximately that
    many tokens (rough estimate: 1 token ≈ 4 chars).  When *explicit_prompt*
    is given it is returned unchanged.
    """
    if explicit_prompt:
        return explicit_prompt
    if target_tokens is None:
        return "Explain the importance of low-latency inference in production AI systems."
    target_chars = target_tokens * 4
    repeated = (_FILLER_SENTENCE * math.ceil(target_chars / len(_FILLER_SENTENCE)))
    return repeated[:target_chars]


# ---------------------------------------------------------------------------
# Core benchmark loop
# ---------------------------------------------------------------------------

def _run_iteration(
    iteration: int,
    model: str,
    prompt: str,
    max_tokens: int,
    temperature: float,
) -> RunResult:
    """Execute one generation request and capture timing."""
    from mlx_container import generate

    t0 = time.perf_counter()
    try:
        result = generate(
            prompt=prompt,
            model=model,
            max_tokens=max_tokens,
            temperature=temperature,
            stream=False,
        )
        wall_time = time.perf_counter() - t0
        return RunResult(
            iteration=iteration,
            success=True,
            prompt_tokens=result.prompt_tokens,
            completion_tokens=result.completion_tokens,
            prompt_time_seconds=result.prompt_time_seconds,
            generation_time_seconds=result.generation_time_seconds,
            tokens_per_second=result.tokens_per_second,
            wall_time_seconds=wall_time,
        )
    except Exception as exc:
        wall_time = time.perf_counter() - t0
        return RunResult(
            iteration=iteration,
            success=False,
            error=str(exc),
            wall_time_seconds=wall_time,
        )


def run_benchmark(
    model: str,
    prompt: str,
    iterations: int,
    max_tokens: int,
    temperature: float,
    warmup: int = 1,
    verbose: bool = True,
) -> tuple[BenchmarkStats, list[RunResult]]:
    """
    Run the benchmark and return aggregate stats plus all per-run results.

    Args:
        model: Model ID to benchmark.
        prompt: Prompt text to use for every iteration.
        iterations: Number of *measured* iterations (warmup runs are excluded).
        max_tokens: Maximum tokens to generate per call.
        temperature: Sampling temperature (use 0.0 for deterministic output).
        warmup: Number of warmup runs to discard before measurement.
        verbose: Print per-iteration progress.

    Returns:
        (BenchmarkStats, list[RunResult]) — stats aggregate and raw results.
    """
    all_results: list[RunResult] = []

    total_runs = warmup + iterations

    for i in range(total_runs):
        is_warmup = i < warmup
        label = f"warmup {i + 1}/{warmup}" if is_warmup else f"iter {i - warmup + 1}/{iterations}"

        if verbose:
            print(f"  [{label}] ... ", end="", flush=True)

        run = _run_iteration(
            iteration=i,
            model=model,
            prompt=prompt,
            max_tokens=max_tokens,
            temperature=temperature,
        )

        if verbose:
            if run.success:
                print(
                    f"{'(warmup) ' if is_warmup else ''}"
                    f"{run.tokens_per_second:.1f} tok/s, "
                    f"{run.wall_time_seconds:.2f}s"
                )
            else:
                print(f"FAILED: {run.error[:80]}")

        if not is_warmup:
            all_results.append(run)

    successes = [r for r in all_results if r.success]
    failures = [r for r in all_results if not r.success]

    stats = BenchmarkStats(
        model=model,
        prompt=prompt[:120] + ("..." if len(prompt) > 120 else ""),
        max_tokens=max_tokens,
        temperature=temperature,
        total_iterations=len(all_results),
        successful=len(successes),
        failed=len(failures),
        errors=[r.error for r in failures],
    )

    if successes:
        tps_vals = [r.tokens_per_second for r in successes]
        lat_vals = [r.wall_time_seconds for r in successes]
        ttft_vals = [r.prompt_time_seconds for r in successes]

        stats.tps_mean, stats.tps_p50, stats.tps_p95, stats.tps_p99, stats.tps_min, stats.tps_max = (
            _compute_stats(tps_vals)
        )
        stats.latency_mean_s, stats.latency_p50_s, stats.latency_p95_s, stats.latency_p99_s, _, _ = (
            _compute_stats(lat_vals)
        )
        stats.ttft_mean_s, stats.ttft_p50_s, stats.ttft_p95_s, stats.ttft_p99_s, _, _ = (
            _compute_stats(ttft_vals)
        )
        stats.total_tokens_generated = sum(r.completion_tokens for r in successes)
        stats.total_wall_time_s = sum(r.wall_time_seconds for r in successes)
        if stats.total_wall_time_s > 0:
            stats.aggregate_throughput_tps = (
                stats.total_tokens_generated / stats.total_wall_time_s
            )

    return stats, all_results


# ---------------------------------------------------------------------------
# Output formatters
# ---------------------------------------------------------------------------

_USE_COLOUR = sys.stdout.isatty() and os.environ.get("NO_COLOR") is None


def _c(code: str, text: str) -> str:
    return f"\033[{code}m{text}\033[0m" if _USE_COLOUR else text


def _bold(t: str) -> str:
    return _c("1", t)


def _green(t: str) -> str:
    return _c("32", t)


def _yellow(t: str) -> str:
    return _c("33", t)


def _header(t: str) -> str:
    return _c("1;36", t)


def _print_stats(stats: BenchmarkStats) -> None:
    """Print a human-readable benchmark report."""
    bar = "=" * 62
    print()
    print(_header(bar))
    print(_header("  MLX Container Benchmark Report"))
    print(_header(bar))
    print(f"  Model        : {_bold(stats.model)}")
    print(f"  Prompt       : {stats.prompt[:70]}")
    print(f"  Max tokens   : {stats.max_tokens}")
    print(f"  Temperature  : {stats.temperature}")
    print(f"  Iterations   : {stats.total_iterations}  (successful: {stats.successful}, failed: {stats.failed})")
    print()

    if stats.successful == 0:
        print(_yellow("  No successful runs — cannot compute statistics."))
        if stats.errors:
            print("\n  Errors:")
            for e in stats.errors[:5]:
                print(f"    - {e}")
        print()
        return

    print(_bold("  Throughput (tokens/sec)"))
    print(f"    Mean   : {_green(f'{stats.tps_mean:>8.1f}')}")
    print(f"    p50    : {stats.tps_p50:>8.1f}")
    print(f"    p95    : {stats.tps_p95:>8.1f}")
    print(f"    p99    : {stats.tps_p99:>8.1f}")
    print(f"    Min    : {stats.tps_min:>8.1f}")
    print(f"    Max    : {stats.tps_max:>8.1f}")
    print()

    print(_bold("  End-to-End Latency (wall clock, seconds)"))
    print(f"    Mean   : {stats.latency_mean_s:>8.3f}")
    print(f"    p50    : {stats.latency_p50_s:>8.3f}")
    print(f"    p95    : {stats.latency_p95_s:>8.3f}")
    print(f"    p99    : {stats.latency_p99_s:>8.3f}")
    print()

    print(_bold("  Prompt Processing Time / TTFT (seconds)"))
    print(f"    Mean   : {stats.ttft_mean_s:>8.3f}")
    print(f"    p50    : {stats.ttft_p50_s:>8.3f}")
    print(f"    p95    : {stats.ttft_p95_s:>8.3f}")
    print(f"    p99    : {stats.ttft_p99_s:>8.3f}")
    print()

    print(_bold("  Aggregate"))
    print(f"    Tokens generated  : {stats.total_tokens_generated:,}")
    print(f"    Total wall time   : {stats.total_wall_time_s:.2f}s")
    print(f"    Throughput (agg)  : {_green(f'{stats.aggregate_throughput_tps:.1f}')} tok/s")
    print()

    if stats.errors:
        print(_yellow(f"  {stats.failed} iteration(s) failed:"))
        for e in stats.errors[:5]:
            print(f"    - {e[:100]}")
        print()

    print(_header(bar))
    print()


def _print_json(stats: BenchmarkStats, results: list[RunResult]) -> None:
    output: dict[str, Any] = {
        "summary": asdict(stats),
        "runs": [asdict(r) for r in results],
    }
    print(json.dumps(output, indent=2))


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Benchmark MLX Container Toolkit inference performance",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "--model",
        default="mlx-community/Llama-3.2-1B-4bit",
        help="Model ID to benchmark",
    )
    parser.add_argument(
        "--iterations",
        "-n",
        type=int,
        default=10,
        help="Number of measured iterations",
    )
    parser.add_argument(
        "--warmup",
        type=int,
        default=1,
        help="Number of warmup iterations (discarded from stats)",
    )
    parser.add_argument(
        "--max-tokens",
        type=int,
        default=100,
        help="Maximum tokens to generate per request",
    )
    parser.add_argument(
        "--temperature",
        type=float,
        default=0.0,
        help="Sampling temperature (0.0 = deterministic, for reproducibility)",
    )
    prompt_group = parser.add_mutually_exclusive_group()
    prompt_group.add_argument(
        "--prompt",
        default=None,
        help="Explicit prompt text to use for every iteration",
    )
    prompt_group.add_argument(
        "--prompt-tokens",
        type=int,
        default=None,
        metavar="N",
        help="Build a synthetic prompt of approximately N tokens",
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
        help="Output results as JSON (suppresses progress output)",
    )
    parser.add_argument(
        "--no-warmup-skip",
        dest="skip_warmup",
        action="store_false",
        default=True,
        help="Do NOT skip warmup iterations from stats (useful for ablation)",
    )
    return parser.parse_args()


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    args = _parse_args()

    # Transport
    if args.host is not None:
        os.environ["MLX_DAEMON_HOST"] = args.host
    if args.port is not None:
        os.environ["MLX_DAEMON_PORT"] = str(args.port)

    # Validate imports
    try:
        from mlx_container._grpc_client import get_client  # noqa: F401
    except ImportError as exc:
        print(f"mlx_container not found: {exc}", file=sys.stderr)
        print("Install with: pip install -e client/", file=sys.stderr)
        sys.exit(1)

    # Ping daemon
    if not args.as_json:
        print("Connecting to daemon...", end="", flush=True)
    try:
        from mlx_container._grpc_client import get_client
        ping = get_client().ping()
        if not args.as_json:
            print(f" ok (version={ping.get('version', '?')})")
    except Exception as exc:
        print(f"\n[ERROR] Cannot reach daemon: {exc}", file=sys.stderr)
        sys.exit(1)

    # Build prompt
    prompt = _build_prompt(args.prompt_tokens, args.prompt)

    if not args.as_json:
        print(f"\nBenchmarking: {args.model}")
        print(f"  Iterations  : {args.warmup} warmup + {args.iterations} measured")
        print(f"  Max tokens  : {args.max_tokens}")
        print(f"  Temperature : {args.temperature}")
        print(f"  Prompt      : {prompt[:80]}{'...' if len(prompt) > 80 else ''}")
        print()

    stats, results = run_benchmark(
        model=args.model,
        prompt=prompt,
        iterations=args.iterations,
        max_tokens=args.max_tokens,
        temperature=args.temperature,
        warmup=args.warmup if args.skip_warmup else 0,
        verbose=not args.as_json,
    )

    if args.as_json:
        _print_json(stats, results)
    else:
        _print_stats(stats)

    sys.exit(0 if stats.failed == 0 else 1)


if __name__ == "__main__":
    main()
