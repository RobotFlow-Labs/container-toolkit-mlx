"""Tests for mlx_container.proto.mlx_container_pb2 — JSON message classes."""

from __future__ import annotations

import json

import pytest

from mlx_container.proto import mlx_container_pb2 as pb2


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _roundtrip(msg):
    """Serialize then deserialize via SerializeToString / FromString."""
    raw = msg.SerializeToString()
    return type(msg).FromString(raw)


def _json_dict(msg) -> dict:
    """Decode the wire bytes as a plain dict for key-name inspection."""
    return json.loads(msg.SerializeToString().decode("utf-8"))


# ---------------------------------------------------------------------------
# Model management messages
# ---------------------------------------------------------------------------


class TestLoadModelRequest:
    def test_roundtrip_all_fields(self):
        original = pb2.LoadModelRequest(
            model_id="mlx-community/Llama-3.2-1B-4bit",
            alias="llama-small",
            memory_budget_bytes=4_000_000_000,
        )
        decoded = _roundtrip(original)
        assert decoded.model_id == original.model_id
        assert decoded.alias == original.alias
        assert decoded.memory_budget_bytes == original.memory_budget_bytes

    def test_json_key_model_id_is_camelcase(self):
        msg = pb2.LoadModelRequest(model_id="test-model")
        d = _json_dict(msg)
        assert "modelID" in d, "model_id should serialize to camelCase key 'modelID'"
        assert "model_id" not in d

    def test_json_key_memory_budget_bytes_is_camelcase(self):
        msg = pb2.LoadModelRequest(memory_budget_bytes=1_000_000)
        d = _json_dict(msg)
        assert "memoryBudgetBytes" in d
        assert "memory_budget_bytes" not in d

    def test_default_values_roundtrip(self):
        original = pb2.LoadModelRequest()
        decoded = _roundtrip(original)
        assert decoded.model_id == ""
        assert decoded.alias == ""
        assert decoded.memory_budget_bytes == 0

    def test_serialize_produces_bytes(self):
        msg = pb2.LoadModelRequest(model_id="x")
        raw = msg.SerializeToString()
        assert isinstance(raw, bytes)
        assert len(raw) > 0


class TestLoadModelResponse:
    def test_roundtrip_success(self):
        original = pb2.LoadModelResponse(
            success=True,
            model_id="mlx-community/Llama-3.2-1B-4bit",
            memory_used_bytes=1_500_000_000,
            load_time_seconds=3.14,
        )
        decoded = _roundtrip(original)
        assert decoded.success is True
        assert decoded.model_id == original.model_id
        assert decoded.memory_used_bytes == original.memory_used_bytes
        assert decoded.load_time_seconds == pytest.approx(3.14)

    def test_roundtrip_failure_with_error(self):
        original = pb2.LoadModelResponse(success=False, error="Not found")
        decoded = _roundtrip(original)
        assert decoded.success is False
        assert decoded.error == "Not found"

    def test_json_key_is_camelcase(self):
        msg = pb2.LoadModelResponse(load_time_seconds=1.0)
        d = _json_dict(msg)
        assert "loadTimeSeconds" in d
        assert "load_time_seconds" not in d


class TestUnloadModelRequest:
    def test_roundtrip(self):
        original = pb2.UnloadModelRequest(model_id="mlx-community/Llama-3.2-1B-4bit")
        decoded = _roundtrip(original)
        assert decoded.model_id == original.model_id

    def test_json_key_is_camelcase(self):
        msg = pb2.UnloadModelRequest(model_id="x")
        d = _json_dict(msg)
        assert "modelID" in d


class TestUnloadModelResponse:
    def test_roundtrip(self):
        original = pb2.UnloadModelResponse(
            success=True,
            error="",
            memory_freed_bytes=1_200_000_000,
        )
        decoded = _roundtrip(original)
        assert decoded.success is True
        assert decoded.memory_freed_bytes == 1_200_000_000

    def test_json_key_memory_freed_is_camelcase(self):
        msg = pb2.UnloadModelResponse(memory_freed_bytes=100)
        d = _json_dict(msg)
        assert "memoryFreedBytes" in d


class TestListModelsRequest:
    def test_roundtrip_empty_message(self):
        original = pb2.ListModelsRequest()
        _ = _roundtrip(original)  # must not raise

    def test_serializes_as_empty_json_object(self):
        msg = pb2.ListModelsRequest()
        d = _json_dict(msg)
        assert d == {}, "ListModelsRequest should serialize to an empty JSON object"


class TestListModelsResponse:
    def test_roundtrip_empty_models(self):
        original = pb2.ListModelsResponse(models=[])
        decoded = _roundtrip(original)
        assert decoded.models == []

    def test_roundtrip_with_models(self):
        models = [
            pb2.ModelInfo(model_id="model-a", alias="a", is_loaded=True),
            pb2.ModelInfo(model_id="model-b", alias="b", is_loaded=False),
        ]
        original = pb2.ListModelsResponse(models=models)
        decoded = _roundtrip(original)
        assert len(decoded.models) == 2
        assert decoded.models[0].model_id == "model-a"
        assert decoded.models[1].model_id == "model-b"


class TestModelInfo:
    def test_roundtrip_all_fields(self):
        original = pb2.ModelInfo(
            model_id="mlx-community/Qwen2.5-1.5B-4bit",
            alias="qwen",
            memory_used_bytes=750_000_000,
            is_loaded=True,
            model_type="llm",
        )
        decoded = _roundtrip(original)
        assert decoded.model_id == original.model_id
        assert decoded.alias == original.alias
        assert decoded.memory_used_bytes == original.memory_used_bytes
        assert decoded.is_loaded is True
        assert decoded.model_type == original.model_type

    def test_json_key_model_id_is_camelcase(self):
        msg = pb2.ModelInfo(model_id="m")
        d = _json_dict(msg)
        assert "modelID" in d

    def test_json_key_is_loaded_is_camelcase(self):
        msg = pb2.ModelInfo(is_loaded=True)
        d = _json_dict(msg)
        assert "isLoaded" in d

    def test_json_key_memory_used_bytes_is_camelcase(self):
        msg = pb2.ModelInfo(memory_used_bytes=100)
        d = _json_dict(msg)
        assert "memoryUsedBytes" in d


# ---------------------------------------------------------------------------
# Inference messages
# ---------------------------------------------------------------------------


class TestChatMessage:
    def test_roundtrip(self):
        original = pb2.ChatMessage(role="user", content="Hello!")
        decoded = _roundtrip(original)
        assert decoded.role == "user"
        assert decoded.content == "Hello!"

    def test_json_keys_match_swift(self):
        msg = pb2.ChatMessage(role="assistant", content="42")
        d = _json_dict(msg)
        assert "role" in d
        assert "content" in d


class TestGenerateParameters:
    def test_roundtrip_all_fields(self):
        original = pb2.GenerateParameters(
            max_tokens=512,
            temperature=0.7,
            top_p=0.9,
            repetition_penalty=1.1,
            repetition_context_size=20,
        )
        decoded = _roundtrip(original)
        assert decoded.max_tokens == 512
        assert decoded.temperature == pytest.approx(0.7)
        assert decoded.top_p == pytest.approx(0.9)
        assert decoded.repetition_penalty == pytest.approx(1.1)
        assert decoded.repetition_context_size == 20

    def test_json_keys_are_camelcase(self):
        msg = pb2.GenerateParameters(max_tokens=100, top_p=0.5, repetition_penalty=1.0,
                                      repetition_context_size=10)
        d = _json_dict(msg)
        assert "maxTokens" in d
        assert "topP" in d
        assert "repetitionPenalty" in d
        assert "repetitionContextSize" in d
        assert "max_tokens" not in d


class TestGenerateRequest:
    def test_roundtrip_with_messages_and_parameters(self, sample_chat_messages, sample_generate_parameters):
        original = pb2.GenerateRequest(
            model_id="mlx-community/Llama-3.2-3B-4bit",
            prompt="",
            messages=sample_chat_messages,
            parameters=sample_generate_parameters,
            container_id="ctr-007",
        )
        decoded = _roundtrip(original)
        assert decoded.model_id == original.model_id
        assert decoded.container_id == "ctr-007"
        assert len(decoded.messages) == 2
        assert decoded.messages[0].role == "system"
        assert decoded.messages[1].content == "What is 2+2?"
        assert decoded.parameters.max_tokens == 512

    def test_roundtrip_with_prompt_no_messages(self):
        original = pb2.GenerateRequest(model_id="m", prompt="Once upon a time")
        decoded = _roundtrip(original)
        assert decoded.prompt == "Once upon a time"
        assert decoded.messages == []

    def test_json_keys_are_camelcase(self):
        msg = pb2.GenerateRequest(model_id="m", container_id="c")
        d = _json_dict(msg)
        assert "modelID" in d
        assert "containerID" in d
        assert "model_id" not in d


class TestGenerateResponse:
    def test_has_field_token_when_token_set(self):
        msg = pb2.GenerateResponse(token="hello")
        assert msg.HasField("token") is True
        assert msg.HasField("complete") is False

    def test_has_field_complete_when_complete_set(self, sample_generate_complete):
        msg = pb2.GenerateResponse(complete=sample_generate_complete)
        assert msg.HasField("complete") is True
        assert msg.HasField("token") is False

    def test_has_field_both_false_when_empty(self):
        msg = pb2.GenerateResponse()
        assert msg.HasField("token") is False
        assert msg.HasField("complete") is False

    def test_from_string_token_variant(self):
        raw = json.dumps({"token": "world"}).encode("utf-8")
        msg = pb2.GenerateResponse.FromString(raw)
        assert msg.HasField("token") is True
        assert msg.token == "world"
        assert msg.HasField("complete") is False

    def test_from_string_complete_variant(self):
        payload = {
            "complete": {
                "fullText": "Hello world",
                "promptTokens": 5,
                "completionTokens": 3,
                "promptTimeSeconds": 0.01,
                "generationTimeSeconds": 0.2,
                "tokensPerSecond": 15.0,
            }
        }
        raw = json.dumps(payload).encode("utf-8")
        msg = pb2.GenerateResponse.FromString(raw)
        assert msg.HasField("complete") is True
        assert msg.complete.full_text == "Hello world"
        assert msg.complete.prompt_tokens == 5
        assert msg.complete.tokens_per_second == pytest.approx(15.0)

    def test_from_string_empty_object(self):
        raw = json.dumps({}).encode("utf-8")
        msg = pb2.GenerateResponse.FromString(raw)
        assert msg.HasField("token") is False
        assert msg.HasField("complete") is False


class TestGenerateComplete:
    def test_roundtrip_all_fields(self, sample_generate_complete):
        decoded = _roundtrip(sample_generate_complete)
        assert decoded.full_text == sample_generate_complete.full_text
        assert decoded.prompt_tokens == sample_generate_complete.prompt_tokens
        assert decoded.completion_tokens == sample_generate_complete.completion_tokens
        assert decoded.tokens_per_second == pytest.approx(sample_generate_complete.tokens_per_second)

    def test_json_keys_are_camelcase(self):
        msg = pb2.GenerateComplete(full_text="x", prompt_tokens=1, completion_tokens=1,
                                    generation_time_seconds=0.1, tokens_per_second=10.0)
        d = _json_dict(msg)
        assert "fullText" in d
        assert "promptTokens" in d
        assert "completionTokens" in d
        assert "generationTimeSeconds" in d
        assert "tokensPerSecond" in d


# ---------------------------------------------------------------------------
# Health & Status messages
# ---------------------------------------------------------------------------


class TestPingRequest:
    def test_roundtrip_empty_message(self):
        _ = _roundtrip(pb2.PingRequest())  # must not raise

    def test_serializes_as_empty_json_object(self):
        d = _json_dict(pb2.PingRequest())
        assert d == {}


class TestPingResponse:
    def test_roundtrip_all_fields(self):
        original = pb2.PingResponse(status="ok", version="0.1.0", uptime_seconds=3600.5)
        decoded = _roundtrip(original)
        assert decoded.status == "ok"
        assert decoded.version == "0.1.0"
        assert decoded.uptime_seconds == pytest.approx(3600.5)

    def test_json_key_uptime_is_camelcase(self):
        msg = pb2.PingResponse(uptime_seconds=1.0)
        d = _json_dict(msg)
        assert "uptimeSeconds" in d
        assert "uptime_seconds" not in d


class TestGetGPUStatusRequest:
    def test_roundtrip_empty_message(self):
        _ = _roundtrip(pb2.GetGPUStatusRequest())

    def test_serializes_as_empty_json_object(self):
        d = _json_dict(pb2.GetGPUStatusRequest())
        assert d == {}


class TestGetGPUStatusResponse:
    def test_roundtrip_all_fields(self):
        original = pb2.GetGPUStatusResponse(
            device_name="Apple M3 Pro",
            total_memory_bytes=18_000_000_000,
            used_memory_bytes=800_000_000,
            available_memory_bytes=17_200_000_000,
            gpu_family="metal3",
            loaded_models_count=1,
            loaded_models=[pb2.ModelInfo(model_id="llama", is_loaded=True)],
        )
        decoded = _roundtrip(original)
        assert decoded.device_name == "Apple M3 Pro"
        assert decoded.total_memory_bytes == 18_000_000_000
        assert decoded.gpu_family == "metal3"
        assert decoded.loaded_models_count == 1
        assert len(decoded.loaded_models) == 1
        assert decoded.loaded_models[0].model_id == "llama"

    def test_json_keys_are_camelcase(self):
        msg = pb2.GetGPUStatusResponse(device_name="GPU", total_memory_bytes=1,
                                        used_memory_bytes=0, available_memory_bytes=1,
                                        loaded_models_count=0)
        d = _json_dict(msg)
        assert "deviceName" in d
        assert "totalMemoryBytes" in d
        assert "usedMemoryBytes" in d
        assert "availableMemoryBytes" in d
        assert "loadedModelsCount" in d
        assert "device_name" not in d


# ---------------------------------------------------------------------------
# Embedding messages
# ---------------------------------------------------------------------------


class TestEmbedRequest:
    def test_roundtrip(self):
        original = pb2.EmbedRequest(
            model_id="mlx-community/bge-small-en-v1.5",
            texts=["Hello", "World"],
            container_id="ctr-embed",
        )
        decoded = _roundtrip(original)
        assert decoded.model_id == original.model_id
        assert decoded.texts == ["Hello", "World"]
        assert decoded.container_id == "ctr-embed"

    def test_json_keys_are_camelcase(self):
        msg = pb2.EmbedRequest(model_id="m", container_id="c")
        d = _json_dict(msg)
        assert "modelID" in d
        assert "containerID" in d


class TestEmbedResponse:
    def test_roundtrip_with_embeddings(self):
        original = pb2.EmbedResponse(
            embeddings=[
                pb2.Embedding(values=[0.1, 0.2, 0.3]),
                pb2.Embedding(values=[0.4, 0.5, 0.6]),
            ],
            error="",
        )
        decoded = _roundtrip(original)
        assert len(decoded.embeddings) == 2
        assert decoded.embeddings[0].values == pytest.approx([0.1, 0.2, 0.3])
        assert decoded.embeddings[1].values == pytest.approx([0.4, 0.5, 0.6])

    def test_roundtrip_empty(self):
        original = pb2.EmbedResponse()
        decoded = _roundtrip(original)
        assert decoded.embeddings == []
        assert decoded.error == ""
