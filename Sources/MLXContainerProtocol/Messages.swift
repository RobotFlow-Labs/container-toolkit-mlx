import Foundation
import SwiftProtobuf

// MARK: - Model Management Messages

public struct MLXContainer_LoadModelRequest: Sendable, SwiftProtobuf.Message {
    public static let protoMessageName = "mlx_container.v1.LoadModelRequest"

    public var modelID: String = ""
    public var alias: String = ""
    public var memoryBudgetBytes: UInt64 = 0

    public init() {}

    public init(modelID: String, alias: String = "", memoryBudgetBytes: UInt64 = 0) {
        self.modelID = modelID
        self.alias = alias
        self.memoryBudgetBytes = memoryBudgetBytes
    }

    public var unknownFields = SwiftProtobuf.UnknownStorage()

    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularStringField(value: &modelID)
            case 2: try decoder.decodeSingularStringField(value: &alias)
            case 3: try decoder.decodeSingularUInt64Field(value: &memoryBudgetBytes)
            default: break
            }
        }
    }

    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !modelID.isEmpty { try visitor.visitSingularStringField(value: modelID, fieldNumber: 1) }
        if !alias.isEmpty { try visitor.visitSingularStringField(value: alias, fieldNumber: 2) }
        if memoryBudgetBytes != 0 { try visitor.visitSingularUInt64Field(value: memoryBudgetBytes, fieldNumber: 3) }
        try unknownFields.traverse(visitor: &visitor)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.modelID == rhs.modelID && lhs.alias == rhs.alias && lhs.memoryBudgetBytes == rhs.memoryBudgetBytes
    }
}

public struct MLXContainer_LoadModelResponse: Sendable, SwiftProtobuf.Message {
    public static let protoMessageName = "mlx_container.v1.LoadModelResponse"

    public var success: Bool = false
    public var modelID: String = ""
    public var error: String = ""
    public var memoryUsedBytes: UInt64 = 0
    public var loadTimeSeconds: Double = 0

    public init() {}
    public var unknownFields = SwiftProtobuf.UnknownStorage()

    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularBoolField(value: &success)
            case 2: try decoder.decodeSingularStringField(value: &modelID)
            case 3: try decoder.decodeSingularStringField(value: &error)
            case 4: try decoder.decodeSingularUInt64Field(value: &memoryUsedBytes)
            case 5: try decoder.decodeSingularDoubleField(value: &loadTimeSeconds)
            default: break
            }
        }
    }

    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if success { try visitor.visitSingularBoolField(value: success, fieldNumber: 1) }
        if !modelID.isEmpty { try visitor.visitSingularStringField(value: modelID, fieldNumber: 2) }
        if !error.isEmpty { try visitor.visitSingularStringField(value: error, fieldNumber: 3) }
        if memoryUsedBytes != 0 { try visitor.visitSingularUInt64Field(value: memoryUsedBytes, fieldNumber: 4) }
        if loadTimeSeconds != 0 { try visitor.visitSingularDoubleField(value: loadTimeSeconds, fieldNumber: 5) }
        try unknownFields.traverse(visitor: &visitor)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.success == rhs.success && lhs.modelID == rhs.modelID && lhs.error == rhs.error
    }
}

public struct MLXContainer_UnloadModelRequest: Sendable, SwiftProtobuf.Message {
    public static let protoMessageName = "mlx_container.v1.UnloadModelRequest"
    public var modelID: String = ""
    public init() {}
    public init(modelID: String) { self.modelID = modelID }
    public var unknownFields = SwiftProtobuf.UnknownStorage()

    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularStringField(value: &modelID)
            default: break
            }
        }
    }

    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !modelID.isEmpty { try visitor.visitSingularStringField(value: modelID, fieldNumber: 1) }
        try unknownFields.traverse(visitor: &visitor)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.modelID == rhs.modelID }
}

public struct MLXContainer_UnloadModelResponse: Sendable, SwiftProtobuf.Message {
    public static let protoMessageName = "mlx_container.v1.UnloadModelResponse"
    public var success: Bool = false
    public var error: String = ""
    public var memoryFreedBytes: UInt64 = 0
    public init() {}
    public var unknownFields = SwiftProtobuf.UnknownStorage()

    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularBoolField(value: &success)
            case 2: try decoder.decodeSingularStringField(value: &error)
            case 3: try decoder.decodeSingularUInt64Field(value: &memoryFreedBytes)
            default: break
            }
        }
    }

    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if success { try visitor.visitSingularBoolField(value: success, fieldNumber: 1) }
        if !error.isEmpty { try visitor.visitSingularStringField(value: error, fieldNumber: 2) }
        if memoryFreedBytes != 0 { try visitor.visitSingularUInt64Field(value: memoryFreedBytes, fieldNumber: 3) }
        try unknownFields.traverse(visitor: &visitor)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.success == rhs.success }
}

public struct MLXContainer_ListModelsRequest: Sendable, SwiftProtobuf.Message {
    public static let protoMessageName = "mlx_container.v1.ListModelsRequest"
    public init() {}
    public var unknownFields = SwiftProtobuf.UnknownStorage()
    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {}
    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        try unknownFields.traverse(visitor: &visitor)
    }
    public static func == (lhs: Self, rhs: Self) -> Bool { true }
}

public struct MLXContainer_ListModelsResponse: Sendable, SwiftProtobuf.Message {
    public static let protoMessageName = "mlx_container.v1.ListModelsResponse"
    public var models: [MLXContainer_ModelInfo] = []
    public init() {}
    public var unknownFields = SwiftProtobuf.UnknownStorage()

    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeRepeatedMessageField(value: &models)
            default: break
            }
        }
    }

    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !models.isEmpty { try visitor.visitRepeatedMessageField(value: models, fieldNumber: 1) }
        try unknownFields.traverse(visitor: &visitor)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.models == rhs.models }
}

public struct MLXContainer_ModelInfo: Sendable, SwiftProtobuf.Message, Equatable {
    public static let protoMessageName = "mlx_container.v1.ModelInfo"
    public var modelID: String = ""
    public var alias: String = ""
    public var memoryUsedBytes: UInt64 = 0
    public var isLoaded: Bool = false
    public var modelType: String = ""
    public init() {}
    public var unknownFields = SwiftProtobuf.UnknownStorage()

    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularStringField(value: &modelID)
            case 2: try decoder.decodeSingularStringField(value: &alias)
            case 3: try decoder.decodeSingularUInt64Field(value: &memoryUsedBytes)
            case 4: try decoder.decodeSingularBoolField(value: &isLoaded)
            case 5: try decoder.decodeSingularStringField(value: &modelType)
            default: break
            }
        }
    }

    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !modelID.isEmpty { try visitor.visitSingularStringField(value: modelID, fieldNumber: 1) }
        if !alias.isEmpty { try visitor.visitSingularStringField(value: alias, fieldNumber: 2) }
        if memoryUsedBytes != 0 { try visitor.visitSingularUInt64Field(value: memoryUsedBytes, fieldNumber: 3) }
        if isLoaded { try visitor.visitSingularBoolField(value: isLoaded, fieldNumber: 4) }
        if !modelType.isEmpty { try visitor.visitSingularStringField(value: modelType, fieldNumber: 5) }
        try unknownFields.traverse(visitor: &visitor)
    }
}

// MARK: - Inference Messages

public struct MLXContainer_ChatMessage: Sendable, SwiftProtobuf.Message, Equatable {
    public static let protoMessageName = "mlx_container.v1.ChatMessage"
    public var role: String = ""
    public var content: String = ""
    public init() {}
    public init(role: String, content: String) { self.role = role; self.content = content }
    public var unknownFields = SwiftProtobuf.UnknownStorage()

    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularStringField(value: &role)
            case 2: try decoder.decodeSingularStringField(value: &content)
            default: break
            }
        }
    }

    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !role.isEmpty { try visitor.visitSingularStringField(value: role, fieldNumber: 1) }
        if !content.isEmpty { try visitor.visitSingularStringField(value: content, fieldNumber: 2) }
        try unknownFields.traverse(visitor: &visitor)
    }
}

public struct MLXContainer_GenerateParameters: Sendable, SwiftProtobuf.Message, Equatable {
    public static let protoMessageName = "mlx_container.v1.GenerateParameters"
    public var maxTokens: Int32 = 0
    public var temperature: Float = 0
    public var topP: Float = 0
    public var repetitionPenalty: Float = 0
    public var repetitionContextSize: Int32 = 0
    public init() {}
    public var unknownFields = SwiftProtobuf.UnknownStorage()

    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularInt32Field(value: &maxTokens)
            case 2: try decoder.decodeSingularFloatField(value: &temperature)
            case 3: try decoder.decodeSingularFloatField(value: &topP)
            case 4: try decoder.decodeSingularFloatField(value: &repetitionPenalty)
            case 5: try decoder.decodeSingularInt32Field(value: &repetitionContextSize)
            default: break
            }
        }
    }

    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if maxTokens != 0 { try visitor.visitSingularInt32Field(value: maxTokens, fieldNumber: 1) }
        if temperature != 0 { try visitor.visitSingularFloatField(value: temperature, fieldNumber: 2) }
        if topP != 0 { try visitor.visitSingularFloatField(value: topP, fieldNumber: 3) }
        if repetitionPenalty != 0 { try visitor.visitSingularFloatField(value: repetitionPenalty, fieldNumber: 4) }
        if repetitionContextSize != 0 { try visitor.visitSingularInt32Field(value: repetitionContextSize, fieldNumber: 5) }
        try unknownFields.traverse(visitor: &visitor)
    }
}

public struct MLXContainer_GenerateRequest: Sendable, SwiftProtobuf.Message {
    public static let protoMessageName = "mlx_container.v1.GenerateRequest"
    public var modelID: String = ""
    public var prompt: String = ""
    public var messages: [MLXContainer_ChatMessage] = []
    public var parameters: MLXContainer_GenerateParameters = .init()
    public var containerID: String = ""
    public init() {}
    public var unknownFields = SwiftProtobuf.UnknownStorage()

    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularStringField(value: &modelID)
            case 2: try decoder.decodeSingularStringField(value: &prompt)
            case 3: try decoder.decodeRepeatedMessageField(value: &messages)
            case 4: try decoder.decodeSingularMessageField(value: &parameters)
            case 5: try decoder.decodeSingularStringField(value: &containerID)
            default: break
            }
        }
    }

    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !modelID.isEmpty { try visitor.visitSingularStringField(value: modelID, fieldNumber: 1) }
        if !prompt.isEmpty { try visitor.visitSingularStringField(value: prompt, fieldNumber: 2) }
        if !messages.isEmpty { try visitor.visitRepeatedMessageField(value: messages, fieldNumber: 3) }
        try visitor.visitSingularMessageField(value: parameters, fieldNumber: 4)
        if !containerID.isEmpty { try visitor.visitSingularStringField(value: containerID, fieldNumber: 5) }
        try unknownFields.traverse(visitor: &visitor)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.modelID == rhs.modelID && lhs.prompt == rhs.prompt && lhs.containerID == rhs.containerID
    }
}

public struct MLXContainer_GenerateComplete: Sendable, SwiftProtobuf.Message, Equatable {
    public static let protoMessageName = "mlx_container.v1.GenerateComplete"
    public var fullText: String = ""
    public var promptTokens: Int32 = 0
    public var completionTokens: Int32 = 0
    public var promptTimeSeconds: Double = 0
    public var generationTimeSeconds: Double = 0
    public var tokensPerSecond: Double = 0
    public init() {}
    public var unknownFields = SwiftProtobuf.UnknownStorage()

    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularStringField(value: &fullText)
            case 2: try decoder.decodeSingularInt32Field(value: &promptTokens)
            case 3: try decoder.decodeSingularInt32Field(value: &completionTokens)
            case 4: try decoder.decodeSingularDoubleField(value: &promptTimeSeconds)
            case 5: try decoder.decodeSingularDoubleField(value: &generationTimeSeconds)
            case 6: try decoder.decodeSingularDoubleField(value: &tokensPerSecond)
            default: break
            }
        }
    }

    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !fullText.isEmpty { try visitor.visitSingularStringField(value: fullText, fieldNumber: 1) }
        if promptTokens != 0 { try visitor.visitSingularInt32Field(value: promptTokens, fieldNumber: 2) }
        if completionTokens != 0 { try visitor.visitSingularInt32Field(value: completionTokens, fieldNumber: 3) }
        if promptTimeSeconds != 0 { try visitor.visitSingularDoubleField(value: promptTimeSeconds, fieldNumber: 4) }
        if generationTimeSeconds != 0 { try visitor.visitSingularDoubleField(value: generationTimeSeconds, fieldNumber: 5) }
        if tokensPerSecond != 0 { try visitor.visitSingularDoubleField(value: tokensPerSecond, fieldNumber: 6) }
        try unknownFields.traverse(visitor: &visitor)
    }
}

public struct MLXContainer_GenerateResponse: Sendable, SwiftProtobuf.Message {
    public static let protoMessageName = "mlx_container.v1.GenerateResponse"

    public enum OneOf_Response: Sendable, Equatable {
        case token(String)
        case complete(MLXContainer_GenerateComplete)
    }

    public var response: OneOf_Response?
    public init() {}
    public init(token: String) { self.response = .token(token) }
    public init(complete: MLXContainer_GenerateComplete) { self.response = .complete(complete) }
    public var unknownFields = SwiftProtobuf.UnknownStorage()

    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1:
                var v: String = ""
                try decoder.decodeSingularStringField(value: &v)
                response = .token(v)
            case 2:
                var v = MLXContainer_GenerateComplete()
                try decoder.decodeSingularMessageField(value: &v)
                response = .complete(v)
            default: break
            }
        }
    }

    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        switch response {
        case .token(let v): try visitor.visitSingularStringField(value: v, fieldNumber: 1)
        case .complete(let v): try visitor.visitSingularMessageField(value: v, fieldNumber: 2)
        case nil: break
        }
        try unknownFields.traverse(visitor: &visitor)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.response == rhs.response }
}

public struct MLXContainer_EmbedRequest: Sendable, SwiftProtobuf.Message {
    public static let protoMessageName = "mlx_container.v1.EmbedRequest"
    public var modelID: String = ""
    public var texts: [String] = []
    public var containerID: String = ""
    public init() {}
    public var unknownFields = SwiftProtobuf.UnknownStorage()

    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularStringField(value: &modelID)
            case 2: try decoder.decodeRepeatedStringField(value: &texts)
            case 3: try decoder.decodeSingularStringField(value: &containerID)
            default: break
            }
        }
    }

    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !modelID.isEmpty { try visitor.visitSingularStringField(value: modelID, fieldNumber: 1) }
        if !texts.isEmpty { try visitor.visitRepeatedStringField(value: texts, fieldNumber: 2) }
        if !containerID.isEmpty { try visitor.visitSingularStringField(value: containerID, fieldNumber: 3) }
        try unknownFields.traverse(visitor: &visitor)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.modelID == rhs.modelID && lhs.texts == rhs.texts }
}

public struct MLXContainer_Embedding: Sendable, SwiftProtobuf.Message, Equatable {
    public static let protoMessageName = "mlx_container.v1.Embedding"
    public var values: [Float] = []
    public init() {}
    public var unknownFields = SwiftProtobuf.UnknownStorage()

    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeRepeatedFloatField(value: &values)
            default: break
            }
        }
    }

    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !values.isEmpty { try visitor.visitPackedFloatField(value: values, fieldNumber: 1) }
        try unknownFields.traverse(visitor: &visitor)
    }
}

public struct MLXContainer_EmbedResponse: Sendable, SwiftProtobuf.Message {
    public static let protoMessageName = "mlx_container.v1.EmbedResponse"
    public var embeddings: [MLXContainer_Embedding] = []
    public var error: String = ""
    public init() {}
    public var unknownFields = SwiftProtobuf.UnknownStorage()

    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeRepeatedMessageField(value: &embeddings)
            case 2: try decoder.decodeSingularStringField(value: &error)
            default: break
            }
        }
    }

    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !embeddings.isEmpty { try visitor.visitRepeatedMessageField(value: embeddings, fieldNumber: 1) }
        if !error.isEmpty { try visitor.visitSingularStringField(value: error, fieldNumber: 2) }
        try unknownFields.traverse(visitor: &visitor)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.embeddings == rhs.embeddings }
}

// MARK: - Health & Status

public struct MLXContainer_GetGPUStatusRequest: Sendable, SwiftProtobuf.Message {
    public static let protoMessageName = "mlx_container.v1.GetGPUStatusRequest"
    public init() {}
    public var unknownFields = SwiftProtobuf.UnknownStorage()
    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {}
    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        try unknownFields.traverse(visitor: &visitor)
    }
    public static func == (lhs: Self, rhs: Self) -> Bool { true }
}

public struct MLXContainer_GetGPUStatusResponse: Sendable, SwiftProtobuf.Message {
    public static let protoMessageName = "mlx_container.v1.GetGPUStatusResponse"
    public var deviceName: String = ""
    public var totalMemoryBytes: UInt64 = 0
    public var usedMemoryBytes: UInt64 = 0
    public var availableMemoryBytes: UInt64 = 0
    public var gpuFamily: String = ""
    public var loadedModelsCount: Int32 = 0
    public var loadedModels: [MLXContainer_ModelInfo] = []
    public init() {}
    public var unknownFields = SwiftProtobuf.UnknownStorage()

    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularStringField(value: &deviceName)
            case 2: try decoder.decodeSingularUInt64Field(value: &totalMemoryBytes)
            case 3: try decoder.decodeSingularUInt64Field(value: &usedMemoryBytes)
            case 4: try decoder.decodeSingularUInt64Field(value: &availableMemoryBytes)
            case 5: try decoder.decodeSingularStringField(value: &gpuFamily)
            case 6: try decoder.decodeSingularInt32Field(value: &loadedModelsCount)
            case 7: try decoder.decodeRepeatedMessageField(value: &loadedModels)
            default: break
            }
        }
    }

    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !deviceName.isEmpty { try visitor.visitSingularStringField(value: deviceName, fieldNumber: 1) }
        if totalMemoryBytes != 0 { try visitor.visitSingularUInt64Field(value: totalMemoryBytes, fieldNumber: 2) }
        if usedMemoryBytes != 0 { try visitor.visitSingularUInt64Field(value: usedMemoryBytes, fieldNumber: 3) }
        if availableMemoryBytes != 0 { try visitor.visitSingularUInt64Field(value: availableMemoryBytes, fieldNumber: 4) }
        if !gpuFamily.isEmpty { try visitor.visitSingularStringField(value: gpuFamily, fieldNumber: 5) }
        if loadedModelsCount != 0 { try visitor.visitSingularInt32Field(value: loadedModelsCount, fieldNumber: 6) }
        if !loadedModels.isEmpty { try visitor.visitRepeatedMessageField(value: loadedModels, fieldNumber: 7) }
        try unknownFields.traverse(visitor: &visitor)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.deviceName == rhs.deviceName && lhs.totalMemoryBytes == rhs.totalMemoryBytes
    }
}

public struct MLXContainer_PingRequest: Sendable, SwiftProtobuf.Message {
    public static let protoMessageName = "mlx_container.v1.PingRequest"
    public init() {}
    public var unknownFields = SwiftProtobuf.UnknownStorage()
    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {}
    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        try unknownFields.traverse(visitor: &visitor)
    }
    public static func == (lhs: Self, rhs: Self) -> Bool { true }
}

public struct MLXContainer_PingResponse: Sendable, SwiftProtobuf.Message {
    public static let protoMessageName = "mlx_container.v1.PingResponse"
    public var status: String = ""
    public var version: String = ""
    public var uptimeSeconds: Double = 0
    public init() {}
    public var unknownFields = SwiftProtobuf.UnknownStorage()

    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularStringField(value: &status)
            case 2: try decoder.decodeSingularStringField(value: &version)
            case 3: try decoder.decodeSingularDoubleField(value: &uptimeSeconds)
            default: break
            }
        }
    }

    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !status.isEmpty { try visitor.visitSingularStringField(value: status, fieldNumber: 1) }
        if !version.isEmpty { try visitor.visitSingularStringField(value: version, fieldNumber: 2) }
        if uptimeSeconds != 0 { try visitor.visitSingularDoubleField(value: uptimeSeconds, fieldNumber: 3) }
        try unknownFields.traverse(visitor: &visitor)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.status == rhs.status && lhs.version == rhs.version
    }
}
