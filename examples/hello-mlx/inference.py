#!/usr/bin/env python3
"""
Hello MLX — Simple inference example for MLX Container Toolkit.

This script runs INSIDE a Linux container but uses the host's
Apple GPU for inference via the MLX Container Daemon.

Usage:
    container run --gpu --gpu-model mlx-community/Llama-3.2-1B-4bit \
        ghcr.io/robotflow-labs/mlx-container:latest \
        python3 inference.py
"""

from mlx_container import generate, load_model, list_models

MODEL = "mlx-community/Llama-3.2-1B-4bit"


def main():
    print("=" * 60)
    print("MLX Container Toolkit — Hello World")
    print("=" * 60)

    # Step 1: Load a model on the host GPU
    print(f"\n[1] Loading model: {MODEL}")
    load_model(MODEL)

    # Step 2: List loaded models
    print("\n[2] Loaded models:")
    for model in list_models():
        print(f"  - {model.model_id} (loaded: {model.is_loaded})")

    # Step 3: Generate text
    print("\n[3] Generating text...")
    result = generate(
        prompt="Explain what makes Apple Silicon unique in 3 sentences.",
        model=MODEL,
        max_tokens=150,
        temperature=0.7,
    )
    print(f"\nResponse:\n{result.text}")
    print(f"\nStats:")
    print(f"  Tokens/sec: {result.tokens_per_second:.1f}")
    print(f"  Prompt time: {result.prompt_time_seconds:.3f}s")
    print(f"  Generation time: {result.generation_time_seconds:.3f}s")

    # Step 4: Streaming generation
    print("\n[4] Streaming generation:")
    print("Q: Write a haiku about containers\nA: ", end="")
    for token in generate(
        prompt="Write a haiku about containers",
        model=MODEL,
        max_tokens=50,
        stream=True,
    ):
        print(token, end="", flush=True)
    print("\n")

    print("=" * 60)
    print("Done! GPU inference from inside a Linux container.")
    print("=" * 60)


if __name__ == "__main__":
    main()
