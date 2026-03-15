"""Data types for the MLX Container client."""

from dataclasses import dataclass, field


@dataclass
class GenerateResult:
    """Result of a text generation request."""

    text: str
    prompt_tokens: int = 0
    completion_tokens: int = 0
    prompt_time_seconds: float = 0.0
    generation_time_seconds: float = 0.0
    tokens_per_second: float = 0.0


@dataclass
class ModelInfo:
    """Information about a loaded model."""

    model_id: str
    alias: str = ""
    memory_used_bytes: int = 0
    is_loaded: bool = False
    model_type: str = "llm"


@dataclass
class GPUStatus:
    """GPU device status."""

    device_name: str
    total_memory_bytes: int = 0
    used_memory_bytes: int = 0
    available_memory_bytes: int = 0
    gpu_family: str = ""
    loaded_models_count: int = 0
    loaded_models: list[ModelInfo] = field(default_factory=list)


@dataclass
class ChatMessage:
    """A chat message with role and content."""

    role: str  # "system", "user", "assistant"
    content: str
