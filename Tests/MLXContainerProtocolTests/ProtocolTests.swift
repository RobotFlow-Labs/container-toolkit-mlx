import XCTest
import Foundation
@testable import MLXContainerProtocol

// MARK: - Helpers

private func roundtrip<T: Codable & Equatable>(_ value: T) throws -> T {
    let data = try JSONEncoder().encode(value)
    return try JSONDecoder().decode(T.self, from: data)
}

private func roundtrip<T: Codable>(_ value: T) throws -> T {
    let data = try JSONEncoder().encode(value)
    return try JSONDecoder().decode(T.self, from: data)
}

// MARK: - Model Management Protocol Tests

final class ModelManagementProtocolTests: XCTestCase {

    func testLoadModelRequestRoundtrip() throws {
        let original = MLXContainer_LoadModelRequest(
            modelID: "mlx-community/Llama-3.2-1B-4bit",
            alias: "llama-small",
            memoryBudgetBytes: 4_000_000_000
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MLXContainer_LoadModelRequest.self, from: data)

        XCTAssertEqual(decoded.modelID, original.modelID)
        XCTAssertEqual(decoded.alias, original.alias)
        XCTAssertEqual(decoded.memoryBudgetBytes, original.memoryBudgetBytes)
    }

    func testLoadModelRequestDefaults() throws {
        let original = MLXContainer_LoadModelRequest()
        let decoded: MLXContainer_LoadModelRequest = try roundtrip(original)
        XCTAssertEqual(decoded.modelID, "")
        XCTAssertEqual(decoded.alias, "")
        XCTAssertEqual(decoded.memoryBudgetBytes, 0)
    }

    func testLoadModelResponseRoundtrip() throws {
        let original = MLXContainer_LoadModelResponse(
            success: true,
            modelID: "mlx-community/Llama-3.2-1B-4bit",
            error: "",
            memoryUsedBytes: 1_500_000_000,
            loadTimeSeconds: 3.14
        )
        let decoded: MLXContainer_LoadModelResponse = try roundtrip(original)

        XCTAssertEqual(decoded.success, true)
        XCTAssertEqual(decoded.modelID, original.modelID)
        XCTAssertEqual(decoded.error, "")
        XCTAssertEqual(decoded.memoryUsedBytes, original.memoryUsedBytes)
        XCTAssertLessThan(abs(decoded.loadTimeSeconds - original.loadTimeSeconds), 0.001)
    }

    func testLoadModelResponseWithError() throws {
        let original = MLXContainer_LoadModelResponse(
            success: false,
            modelID: "bad-model",
            error: "Model not found",
            memoryUsedBytes: 0,
            loadTimeSeconds: 0
        )
        let decoded: MLXContainer_LoadModelResponse = try roundtrip(original)
        XCTAssertEqual(decoded.success, false)
        XCTAssertEqual(decoded.error, "Model not found")
    }

    func testUnloadModelRequestRoundtrip() throws {
        let original = MLXContainer_UnloadModelRequest(modelID: "mlx-community/Llama-3.2-1B-4bit")
        let decoded: MLXContainer_UnloadModelRequest = try roundtrip(original)
        XCTAssertEqual(decoded.modelID, original.modelID)
    }

    func testUnloadModelResponseRoundtrip() throws {
        let original = MLXContainer_UnloadModelResponse(
            success: true,
            error: "",
            memoryFreedBytes: 1_200_000_000
        )
        let decoded: MLXContainer_UnloadModelResponse = try roundtrip(original)
        XCTAssertEqual(decoded.success, true)
        XCTAssertEqual(decoded.memoryFreedBytes, original.memoryFreedBytes)
    }

    func testListModelsRequestRoundtrip() throws {
        let original = MLXContainer_ListModelsRequest()
        let data = try JSONEncoder().encode(original)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertTrue(json?.isEmpty == true, "ListModelsRequest should encode as an empty JSON object")
        // Decode should not throw
        _ = try JSONDecoder().decode(MLXContainer_ListModelsRequest.self, from: data)
    }

    func testListModelsResponseRoundtrip() throws {
        let models = [
            MLXContainer_ModelInfo(modelID: "model-a", alias: "a", memoryUsedBytes: 100, isLoaded: true, modelType: "llm"),
            MLXContainer_ModelInfo(modelID: "model-b", alias: "b", memoryUsedBytes: 200, isLoaded: false, modelType: "llm"),
        ]
        let original = MLXContainer_ListModelsResponse(models: models)
        let decoded: MLXContainer_ListModelsResponse = try roundtrip(original)
        XCTAssertEqual(decoded.models.count, 2)
        XCTAssertEqual(decoded.models[0].modelID, "model-a")
        XCTAssertEqual(decoded.models[1].modelID, "model-b")
    }

    func testListModelsResponseEmpty() throws {
        let original = MLXContainer_ListModelsResponse(models: [])
        let decoded: MLXContainer_ListModelsResponse = try roundtrip(original)
        XCTAssertTrue(decoded.models.isEmpty)
    }

    func testModelInfoRoundtrip() throws {
        let original = MLXContainer_ModelInfo(
            modelID: "mlx-community/Qwen2.5-1.5B-4bit",
            alias: "qwen-small",
            memoryUsedBytes: 750_000_000,
            isLoaded: true,
            modelType: "llm"
        )
        let decoded: MLXContainer_ModelInfo = try roundtrip(original)
        XCTAssertEqual(decoded.modelID, original.modelID)
        XCTAssertEqual(decoded.alias, original.alias)
        XCTAssertEqual(decoded.memoryUsedBytes, original.memoryUsedBytes)
        XCTAssertEqual(decoded.isLoaded, original.isLoaded)
        XCTAssertEqual(decoded.modelType, original.modelType)
    }
}

// MARK: - Inference Protocol Tests

final class InferenceProtocolTests: XCTestCase {

    func testChatMessageRoundtrip() throws {
        let original = MLXContainer_ChatMessage(role: "user", content: "Hello, world!")
        let decoded: MLXContainer_ChatMessage = try roundtrip(original)
        XCTAssertEqual(decoded.role, original.role)
        XCTAssertEqual(decoded.content, original.content)
    }

    func testChatMessageDefaults() throws {
        let original = MLXContainer_ChatMessage()
        let decoded: MLXContainer_ChatMessage = try roundtrip(original)
        XCTAssertEqual(decoded.role, "")
        XCTAssertEqual(decoded.content, "")
    }

    func testGenerateParametersRoundtrip() throws {
        let original = MLXContainer_GenerateParameters(
            maxTokens: 512,
            temperature: 0.7,
            topP: 0.9,
            repetitionPenalty: 1.1,
            repetitionContextSize: 20
        )
        let decoded: MLXContainer_GenerateParameters = try roundtrip(original)
        XCTAssertEqual(decoded.maxTokens, original.maxTokens)
        XCTAssertLessThan(abs(decoded.temperature - original.temperature), 0.001)
        XCTAssertLessThan(abs(decoded.topP - original.topP), 0.001)
        XCTAssertLessThan(abs(decoded.repetitionPenalty - original.repetitionPenalty), 0.001)
        XCTAssertEqual(decoded.repetitionContextSize, original.repetitionContextSize)
    }

    func testGenerateRequestRoundtrip() throws {
        let messages = [
            MLXContainer_ChatMessage(role: "system", content: "You are a helpful assistant."),
            MLXContainer_ChatMessage(role: "user", content: "What is 2+2?"),
        ]
        let params = MLXContainer_GenerateParameters(
            maxTokens: 256,
            temperature: 0.5,
            topP: 1.0,
            repetitionPenalty: 1.0,
            repetitionContextSize: 64
        )
        let original = MLXContainer_GenerateRequest(
            modelID: "mlx-community/Llama-3.2-3B-4bit",
            prompt: "",
            messages: messages,
            parameters: params,
            containerID: "container-007"
        )
        let decoded: MLXContainer_GenerateRequest = try roundtrip(original)

        XCTAssertEqual(decoded.modelID, original.modelID)
        XCTAssertEqual(decoded.containerID, original.containerID)
        XCTAssertEqual(decoded.messages.count, 2)
        XCTAssertEqual(decoded.messages[0].role, "system")
        XCTAssertEqual(decoded.messages[1].content, "What is 2+2?")
        XCTAssertEqual(decoded.parameters.maxTokens, 256)
        XCTAssertLessThan(abs(decoded.parameters.temperature - 0.5), 0.001)
    }

    func testGenerateRequestWithPrompt() throws {
        let original = MLXContainer_GenerateRequest(
            modelID: "mlx-community/SmolLM2-135M-4bit",
            prompt: "Once upon a time",
            messages: [],
            parameters: .init(),
            containerID: ""
        )
        let decoded: MLXContainer_GenerateRequest = try roundtrip(original)
        XCTAssertEqual(decoded.prompt, "Once upon a time")
        XCTAssertTrue(decoded.messages.isEmpty)
    }

    func testGenerateResponseTokenVariant() throws {
        let original = MLXContainer_GenerateResponse(token: "Hello")
        let decoded: MLXContainer_GenerateResponse = try roundtrip(original)
        XCTAssertEqual(decoded.token, "Hello")
        XCTAssertNil(decoded.complete)
    }

    func testGenerateResponseCompleteVariant() throws {
        let complete = MLXContainer_GenerateComplete(
            fullText: "Hello, world!",
            promptTokens: 10,
            completionTokens: 5,
            promptTimeSeconds: 0.05,
            generationTimeSeconds: 1.2,
            tokensPerSecond: 42.0
        )
        let original = MLXContainer_GenerateResponse(complete: complete)
        let decoded: MLXContainer_GenerateResponse = try roundtrip(original)

        XCTAssertNil(decoded.token)
        XCTAssertNotNil(decoded.complete)
        XCTAssertEqual(decoded.complete?.fullText, "Hello, world!")
        XCTAssertEqual(decoded.complete?.promptTokens, 10)
        XCTAssertEqual(decoded.complete?.completionTokens, 5)
        XCTAssertLessThan(abs((decoded.complete?.tokensPerSecond ?? 0) - 42.0), 0.001)
    }

    func testGenerateResponseEmpty() throws {
        let original = MLXContainer_GenerateResponse()
        let decoded: MLXContainer_GenerateResponse = try roundtrip(original)
        XCTAssertNil(decoded.token)
        XCTAssertNil(decoded.complete)
    }

    func testGenerateCompleteRoundtrip() throws {
        let original = MLXContainer_GenerateComplete(
            fullText: "The answer is 42.",
            promptTokens: 8,
            completionTokens: 4,
            promptTimeSeconds: 0.01,
            generationTimeSeconds: 0.5,
            tokensPerSecond: 8.0
        )
        let decoded: MLXContainer_GenerateComplete = try roundtrip(original)
        XCTAssertEqual(decoded.fullText, original.fullText)
        XCTAssertEqual(decoded.promptTokens, original.promptTokens)
        XCTAssertEqual(decoded.completionTokens, original.completionTokens)
        XCTAssertLessThan(abs(decoded.promptTimeSeconds - original.promptTimeSeconds), 0.0001)
        XCTAssertLessThan(abs(decoded.generationTimeSeconds - original.generationTimeSeconds), 0.0001)
        XCTAssertLessThan(abs(decoded.tokensPerSecond - original.tokensPerSecond), 0.001)
    }

    func testEmbedRequestRoundtrip() throws {
        let original = MLXContainer_EmbedRequest(
            modelID: "mlx-community/bge-small-en-v1.5",
            texts: ["Hello", "World", "Embeddings"],
            containerID: "ctr-embed"
        )
        let decoded: MLXContainer_EmbedRequest = try roundtrip(original)
        XCTAssertEqual(decoded.modelID, original.modelID)
        XCTAssertEqual(decoded.texts, original.texts)
        XCTAssertEqual(decoded.containerID, original.containerID)
    }

    func testEmbeddingRoundtrip() throws {
        let original = MLXContainer_Embedding(values: [0.1, 0.2, 0.3, -0.5, 1.0])
        let decoded: MLXContainer_Embedding = try roundtrip(original)
        XCTAssertEqual(decoded.values.count, 5)
        for (a, b) in zip(decoded.values, original.values) {
            XCTAssertLessThan(abs(a - b), 0.0001)
        }
    }

    func testEmbedResponseRoundtrip() throws {
        let original = MLXContainer_EmbedResponse(
            embeddings: [
                MLXContainer_Embedding(values: [0.1, 0.2]),
                MLXContainer_Embedding(values: [0.3, 0.4]),
            ],
            error: ""
        )
        let decoded: MLXContainer_EmbedResponse = try roundtrip(original)
        XCTAssertEqual(decoded.embeddings.count, 2)
        XCTAssertEqual(decoded.error, "")
    }
}

// MARK: - Health & Status Protocol Tests

final class HealthProtocolTests: XCTestCase {

    func testPingRequestRoundtrip() throws {
        let original = MLXContainer_PingRequest()
        let data = try JSONEncoder().encode(original)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertTrue(json?.isEmpty == true, "PingRequest should encode as an empty JSON object")
        _ = try JSONDecoder().decode(MLXContainer_PingRequest.self, from: data)
    }

    func testPingResponseRoundtrip() throws {
        let original = MLXContainer_PingResponse(
            status: "ok",
            version: "0.1.0",
            uptimeSeconds: 3600.5
        )
        let decoded: MLXContainer_PingResponse = try roundtrip(original)
        XCTAssertEqual(decoded.status, "ok")
        XCTAssertEqual(decoded.version, "0.1.0")
        XCTAssertLessThan(abs(decoded.uptimeSeconds - 3600.5), 0.001)
    }

    func testGetGPUStatusRequestRoundtrip() throws {
        let original = MLXContainer_GetGPUStatusRequest()
        let data = try JSONEncoder().encode(original)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertTrue(json?.isEmpty == true, "GetGPUStatusRequest should encode as an empty JSON object")
        _ = try JSONDecoder().decode(MLXContainer_GetGPUStatusRequest.self, from: data)
    }

    func testGetGPUStatusResponseRoundtrip() throws {
        let loadedModels = [
            MLXContainer_ModelInfo(
                modelID: "mlx-community/Llama-3.2-1B-4bit",
                alias: "llama",
                memoryUsedBytes: 800_000_000,
                isLoaded: true,
                modelType: "llm"
            )
        ]
        let original = MLXContainer_GetGPUStatusResponse(
            deviceName: "Apple M3 Pro",
            totalMemoryBytes: 18_000_000_000,
            usedMemoryBytes: 800_000_000,
            availableMemoryBytes: 17_200_000_000,
            gpuFamily: "metal3",
            loadedModelsCount: 1,
            loadedModels: loadedModels
        )
        let decoded: MLXContainer_GetGPUStatusResponse = try roundtrip(original)
        XCTAssertEqual(decoded.deviceName, "Apple M3 Pro")
        XCTAssertEqual(decoded.totalMemoryBytes, original.totalMemoryBytes)
        XCTAssertEqual(decoded.usedMemoryBytes, original.usedMemoryBytes)
        XCTAssertEqual(decoded.availableMemoryBytes, original.availableMemoryBytes)
        XCTAssertEqual(decoded.gpuFamily, "metal3")
        XCTAssertEqual(decoded.loadedModelsCount, 1)
        XCTAssertEqual(decoded.loadedModels.count, 1)
        XCTAssertEqual(decoded.loadedModels[0].modelID, "mlx-community/Llama-3.2-1B-4bit")
    }
}

// MARK: - JSON Serializer Tests

final class JSONSerializerTests: XCTestCase {

    func testSerializerProducesValidJSON() throws {
        let serializer = JSONMessageSerializer<MLXContainer_PingRequest>()
        let msg = MLXContainer_PingRequest()
        // [UInt8] conforms to GRPCContiguousBytes
        let bytes: [UInt8] = try serializer.serialize(msg)
        let data = Data(bytes)
        _ = try JSONSerialization.jsonObject(with: data)
    }

    func testDeserializerRestoresMessage() throws {
        let serializer = JSONMessageSerializer<MLXContainer_PingResponse>()
        let deserializer = JSONMessageDeserializer<MLXContainer_PingResponse>()

        let original = MLXContainer_PingResponse(status: "ok", version: "1.0", uptimeSeconds: 99.0)
        let bytes: [UInt8] = try serializer.serialize(original)
        let restored: MLXContainer_PingResponse = try deserializer.deserialize(bytes)

        XCTAssertEqual(restored.status, "ok")
        XCTAssertEqual(restored.version, "1.0")
        XCTAssertLessThan(abs(restored.uptimeSeconds - 99.0), 0.001)
    }

    func testSerializerDeserializerRoundtrip() throws {
        let serializer = JSONMessageSerializer<MLXContainer_LoadModelRequest>()
        let deserializer = JSONMessageDeserializer<MLXContainer_LoadModelRequest>()

        let original = MLXContainer_LoadModelRequest(
            modelID: "mlx-community/SmolLM2-360M-4bit",
            alias: "smollm",
            memoryBudgetBytes: 500_000_000
        )
        let bytes: [UInt8] = try serializer.serialize(original)
        let restored: MLXContainer_LoadModelRequest = try deserializer.deserialize(bytes)

        XCTAssertEqual(restored.modelID, original.modelID)
        XCTAssertEqual(restored.alias, original.alias)
        XCTAssertEqual(restored.memoryBudgetBytes, original.memoryBudgetBytes)
    }
}
