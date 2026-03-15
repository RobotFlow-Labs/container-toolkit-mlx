import Foundation

// All request message types use custom Decodable to tolerate missing fields
// (clients may omit optional fields). Response types use standard Codable since
// the server always sends complete payloads.

// MARK: - Model Management Messages

public struct MLXContainer_LoadModelRequest: Sendable, Codable {
    public var modelID: String
    public var alias: String
    public var memoryBudgetBytes: UInt64

    public init(modelID: String = "", alias: String = "", memoryBudgetBytes: UInt64 = 0) {
        self.modelID = modelID
        self.alias = alias
        self.memoryBudgetBytes = memoryBudgetBytes
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        modelID = try c.decodeIfPresent(String.self, forKey: .modelID) ?? ""
        alias = try c.decodeIfPresent(String.self, forKey: .alias) ?? ""
        memoryBudgetBytes = try c.decodeIfPresent(UInt64.self, forKey: .memoryBudgetBytes) ?? 0
    }
}

public struct MLXContainer_LoadModelResponse: Sendable, Codable {
    public var success: Bool
    public var modelID: String
    public var error: String
    public var memoryUsedBytes: UInt64
    public var loadTimeSeconds: Double

    public init(success: Bool = false, modelID: String = "", error: String = "",
                memoryUsedBytes: UInt64 = 0, loadTimeSeconds: Double = 0) {
        self.success = success
        self.modelID = modelID
        self.error = error
        self.memoryUsedBytes = memoryUsedBytes
        self.loadTimeSeconds = loadTimeSeconds
    }
}

public struct MLXContainer_UnloadModelRequest: Sendable, Codable {
    public var modelID: String

    public init(modelID: String = "") { self.modelID = modelID }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        modelID = try c.decodeIfPresent(String.self, forKey: .modelID) ?? ""
    }
}

public struct MLXContainer_UnloadModelResponse: Sendable, Codable {
    public var success: Bool
    public var error: String
    public var memoryFreedBytes: UInt64

    public init(success: Bool = false, error: String = "", memoryFreedBytes: UInt64 = 0) {
        self.success = success
        self.error = error
        self.memoryFreedBytes = memoryFreedBytes
    }
}

public struct MLXContainer_ListModelsRequest: Sendable, Codable {
    public init() {}
    public init(from decoder: Decoder) throws {}
}

public struct MLXContainer_ListModelsResponse: Sendable, Codable {
    public var models: [MLXContainer_ModelInfo]
    public init(models: [MLXContainer_ModelInfo] = []) { self.models = models }
}

public struct MLXContainer_ModelInfo: Sendable, Codable {
    public var modelID: String
    public var alias: String
    public var memoryUsedBytes: UInt64
    public var isLoaded: Bool
    public var modelType: String

    public init(modelID: String = "", alias: String = "", memoryUsedBytes: UInt64 = 0,
                isLoaded: Bool = false, modelType: String = "") {
        self.modelID = modelID
        self.alias = alias
        self.memoryUsedBytes = memoryUsedBytes
        self.isLoaded = isLoaded
        self.modelType = modelType
    }
}

// MARK: - Inference Messages

public struct MLXContainer_ChatMessage: Sendable, Codable {
    public var role: String
    public var content: String

    public init(role: String = "", content: String = "") {
        self.role = role
        self.content = content
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        role = try c.decodeIfPresent(String.self, forKey: .role) ?? ""
        content = try c.decodeIfPresent(String.self, forKey: .content) ?? ""
    }
}

public struct MLXContainer_GenerateParameters: Sendable, Codable {
    public var maxTokens: Int32
    public var temperature: Float
    public var topP: Float
    public var repetitionPenalty: Float
    public var repetitionContextSize: Int32

    public init(maxTokens: Int32 = 0, temperature: Float = 0, topP: Float = 0,
                repetitionPenalty: Float = 0, repetitionContextSize: Int32 = 0) {
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.repetitionPenalty = repetitionPenalty
        self.repetitionContextSize = repetitionContextSize
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        maxTokens = try c.decodeIfPresent(Int32.self, forKey: .maxTokens) ?? 0
        temperature = try c.decodeIfPresent(Float.self, forKey: .temperature) ?? 0
        topP = try c.decodeIfPresent(Float.self, forKey: .topP) ?? 0
        repetitionPenalty = try c.decodeIfPresent(Float.self, forKey: .repetitionPenalty) ?? 0
        repetitionContextSize = try c.decodeIfPresent(Int32.self, forKey: .repetitionContextSize) ?? 0
    }
}

public struct MLXContainer_GenerateRequest: Sendable, Codable {
    public var modelID: String
    public var prompt: String
    public var messages: [MLXContainer_ChatMessage]
    public var parameters: MLXContainer_GenerateParameters
    public var containerID: String

    public init(modelID: String = "", prompt: String = "", messages: [MLXContainer_ChatMessage] = [],
                parameters: MLXContainer_GenerateParameters = .init(), containerID: String = "") {
        self.modelID = modelID
        self.prompt = prompt
        self.messages = messages
        self.parameters = parameters
        self.containerID = containerID
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        modelID = try c.decodeIfPresent(String.self, forKey: .modelID) ?? ""
        prompt = try c.decodeIfPresent(String.self, forKey: .prompt) ?? ""
        messages = try c.decodeIfPresent([MLXContainer_ChatMessage].self, forKey: .messages) ?? []
        parameters = try c.decodeIfPresent(MLXContainer_GenerateParameters.self, forKey: .parameters) ?? .init()
        containerID = try c.decodeIfPresent(String.self, forKey: .containerID) ?? ""
    }
}

public struct MLXContainer_GenerateComplete: Sendable, Codable {
    public var fullText: String
    public var promptTokens: Int32
    public var completionTokens: Int32
    public var promptTimeSeconds: Double
    public var generationTimeSeconds: Double
    public var tokensPerSecond: Double

    public init(fullText: String = "", promptTokens: Int32 = 0, completionTokens: Int32 = 0,
                promptTimeSeconds: Double = 0, generationTimeSeconds: Double = 0, tokensPerSecond: Double = 0) {
        self.fullText = fullText
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.promptTimeSeconds = promptTimeSeconds
        self.generationTimeSeconds = generationTimeSeconds
        self.tokensPerSecond = tokensPerSecond
    }
}

public struct MLXContainer_GenerateResponse: Sendable, Codable {
    public var token: String?
    public var complete: MLXContainer_GenerateComplete?

    public init(token: String) { self.token = token; self.complete = nil }
    public init(complete: MLXContainer_GenerateComplete) { self.token = nil; self.complete = complete }
    public init() { self.token = nil; self.complete = nil }
}

public struct MLXContainer_EmbedRequest: Sendable, Codable {
    public var modelID: String
    public var texts: [String]
    public var containerID: String

    public init(modelID: String = "", texts: [String] = [], containerID: String = "") {
        self.modelID = modelID
        self.texts = texts
        self.containerID = containerID
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        modelID = try c.decodeIfPresent(String.self, forKey: .modelID) ?? ""
        texts = try c.decodeIfPresent([String].self, forKey: .texts) ?? []
        containerID = try c.decodeIfPresent(String.self, forKey: .containerID) ?? ""
    }
}

public struct MLXContainer_Embedding: Sendable, Codable {
    public var values: [Float]
    public init(values: [Float] = []) { self.values = values }
}

public struct MLXContainer_EmbedResponse: Sendable, Codable {
    public var embeddings: [MLXContainer_Embedding]
    public var error: String

    public init(embeddings: [MLXContainer_Embedding] = [], error: String = "") {
        self.embeddings = embeddings
        self.error = error
    }
}

// MARK: - Health & Status

public struct MLXContainer_GetGPUStatusRequest: Sendable, Codable {
    public init() {}
    public init(from decoder: Decoder) throws {}
}

public struct MLXContainer_GetGPUStatusResponse: Sendable, Codable {
    public var deviceName: String
    public var totalMemoryBytes: UInt64
    public var usedMemoryBytes: UInt64
    public var availableMemoryBytes: UInt64
    public var gpuFamily: String
    public var loadedModelsCount: Int32
    public var loadedModels: [MLXContainer_ModelInfo]

    public init(deviceName: String = "", totalMemoryBytes: UInt64 = 0, usedMemoryBytes: UInt64 = 0,
                availableMemoryBytes: UInt64 = 0, gpuFamily: String = "", loadedModelsCount: Int32 = 0,
                loadedModels: [MLXContainer_ModelInfo] = []) {
        self.deviceName = deviceName
        self.totalMemoryBytes = totalMemoryBytes
        self.usedMemoryBytes = usedMemoryBytes
        self.availableMemoryBytes = availableMemoryBytes
        self.gpuFamily = gpuFamily
        self.loadedModelsCount = loadedModelsCount
        self.loadedModels = loadedModels
    }
}

public struct MLXContainer_PingRequest: Sendable, Codable {
    public init() {}
    public init(from decoder: Decoder) throws {}
}

public struct MLXContainer_PingResponse: Sendable, Codable {
    public var status: String
    public var version: String
    public var uptimeSeconds: Double

    public init(status: String = "", version: String = "", uptimeSeconds: Double = 0) {
        self.status = status
        self.version = version
        self.uptimeSeconds = uptimeSeconds
    }
}
