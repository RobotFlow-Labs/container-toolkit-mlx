import Foundation
import Logging
import MLX
import MLXLLM
import MLXLMCommon
import MLXContainerProtocol

/// Executes MLX inference using loaded models.
public actor InferenceEngine {
    let modelManager: ModelManager
    let defaultMaxTokens: Int
    let defaultTemperature: Float
    let logger: Logger

    public init(
        modelManager: ModelManager,
        defaultMaxTokens: Int,
        defaultTemperature: Float,
        logger: Logger
    ) {
        self.modelManager = modelManager
        self.defaultMaxTokens = defaultMaxTokens
        self.defaultTemperature = defaultTemperature
        self.logger = logger
    }

    /// Run text generation with streaming callbacks.
    public func generate(
        modelID: String,
        prompt: String,
        messages: [MLXContainer_ChatMessage],
        parameters: MLXContainer_GenerateParameters,
        onToken: @Sendable (String) async throws -> Void,
        onComplete: @Sendable (MLXContainer_GenerateComplete) async throws -> Void
    ) async throws {
        let container = try await modelManager.getModelContainer(id: modelID)

        let maxTokens = parameters.maxTokens > 0 ? Int(parameters.maxTokens) : defaultMaxTokens
        let temperature = parameters.temperature > 0 ? parameters.temperature : defaultTemperature

        let generateParams = GenerateParameters(
            maxTokens: maxTokens,
            temperature: temperature,
            topP: parameters.topP > 0 ? parameters.topP : 1.0,
            repetitionPenalty: parameters.repetitionPenalty > 0 ? parameters.repetitionPenalty : nil,
            repetitionContextSize: parameters.repetitionContextSize > 0 ? Int(parameters.repetitionContextSize) : 20
        )

        // Build user input from prompt or chat messages
        let chatMessages: [Chat.Message]
        if !messages.isEmpty {
            chatMessages = messages.map { msg in
                switch msg.role {
                case "system": return .system(msg.content)
                case "assistant": return .assistant(msg.content)
                default: return .user(msg.content)
                }
            }
        } else {
            chatMessages = [.user(prompt)]
        }

        let userInput = UserInput(chat: chatMessages)

        // Prepare input and generate
        let input = try await container.prepare(input: userInput)

        var fullText = ""
        var promptTokens: Int32 = 0
        let startTime = Date()

        try await container.update { context in
            let genStartTime = Date()

            for await item in MLXLMCommon.generate(
                input: input,
                parameters: generateParams,
                context: context
            ) {
                switch item {
                case .chunk(let text):
                    fullText += text
                    try await onToken(text)

                case .info(let info):
                    let genTime = Date().timeIntervalSince(genStartTime)
                    var complete = MLXContainer_GenerateComplete()
                    complete.fullText = fullText
                    complete.promptTimeSeconds = info.promptTime
                    complete.generationTimeSeconds = genTime
                    complete.tokensPerSecond = info.tokensPerSecond
                    complete.completionTokens = Int32(fullText.count) // approximate
                    try await onComplete(complete)

                case .toolCall:
                    break
                }
            }
        }

        logger.info("Generation complete: \(fullText.count) chars in \(String(format: "%.2f", Date().timeIntervalSince(startTime)))s")
    }
}
