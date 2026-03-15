import Foundation
import Logging
import MLX
import MLXLLM
import MLXLMCommon
import MLXEmbedders
import MLXNN
import MLXContainerProtocol

/// Executes MLX inference using loaded models.
public actor InferenceEngine {
    /// Maximum prompt length in characters. Prompts exceeding this are rejected
    /// before tokenisation to avoid runaway memory usage.
    public static let maxPromptLength: Int = 32_768

    /// Hard ceiling on tokens to generate per request.
    public static let maxTokensCap: Int = 8_192

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
        // Enforce prompt length limit before doing any work.
        let effectivePrompt = messages.isEmpty ? prompt : messages.map(\.content).joined(separator: " ")
        guard effectivePrompt.count <= Self.maxPromptLength else {
            throw InferenceError.promptTooLong(
                length: effectivePrompt.count,
                maxLength: Self.maxPromptLength
            )
        }

        let container = try await modelManager.getModelContainer(id: modelID)

        // Cap maxTokens at the hard ceiling.
        let requestedTokens = parameters.maxTokens > 0 ? Int(parameters.maxTokens) : defaultMaxTokens
        let maxTokens = min(requestedTokens, Self.maxTokensCap)
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

        // Prepare input
        let input = try await container.prepare(input: userInput)

        // Generate with streaming
        let startTime = Date()
        var fullText = ""
        var chunkCount: Int32 = 0
        var completeSent = false

        let stream = try await container.generate(
            input: input,
            parameters: generateParams
        )

        for await item in stream {
            // Check cancellation before processing each token so the loop exits
            // promptly when the calling Task is cancelled (e.g. client disconnect
            // or graceful daemon shutdown).  Flush whatever was generated so far
            // as a complete response rather than dropping it silently.
            if Task.isCancelled {
                let genTime = Date().timeIntervalSince(startTime)
                let partialComplete = MLXContainer_GenerateComplete(
                    fullText: fullText,
                    promptTokens: 0,
                    completionTokens: chunkCount,
                    promptTimeSeconds: 0,
                    generationTimeSeconds: genTime,
                    tokensPerSecond: genTime > 0 ? Double(chunkCount) / genTime : 0
                )
                try await onComplete(partialComplete)
                completeSent = true
                return
            }

            switch item {
            case .chunk(let text):
                fullText += text
                chunkCount += 1
                try await onToken(text)

            case .info(let info):
                let genTime = Date().timeIntervalSince(startTime)
                let complete = MLXContainer_GenerateComplete(
                    fullText: fullText,
                    promptTokens: Int32(info.promptTokenCount),
                    completionTokens: Int32(info.generationTokenCount > 0 ? info.generationTokenCount : Int(chunkCount)),
                    promptTimeSeconds: info.promptTime,
                    generationTimeSeconds: genTime,
                    tokensPerSecond: info.tokensPerSecond
                )
                try await onComplete(complete)
                completeSent = true

            case .toolCall:
                break
            }
        }

        // If the stream ended without emitting .info, synthesise a complete
        // frame so the client always receives exactly one final message.
        if !completeSent {
            let genTime = Date().timeIntervalSince(startTime)
            let fallback = MLXContainer_GenerateComplete(
                fullText: fullText,
                completionTokens: chunkCount,
                generationTimeSeconds: genTime,
                tokensPerSecond: genTime > 0 ? Double(chunkCount) / genTime : 0
            )
            try await onComplete(fallback)
        }

        logger.info("Generation complete: \(fullText.count) chars in \(String(format: "%.2f", Date().timeIntervalSince(startTime)))s")
    }

    /// Compute embeddings for a list of input texts using the loaded LLM's token embedding table.
    ///
    /// This uses the token embedding layer (the first `Embedding` or `QuantizedEmbedding` module
    /// found in the model) to look up per-token vectors, then mean-pools and L2-normalises the
    /// result to produce a single fixed-size vector per text.  No full forward pass is required,
    /// making this fast and memory-efficient.
    ///
    /// For best semantic quality use a dedicated embedding model (e.g. `mlx-community/nomic-embed-text-v1`).
    /// LLM-based embeddings produced here are still useful for similarity search and retrieval tasks.
    public func embed(
        modelID: String,
        texts: [String]
    ) async throws -> [MLXContainer_Embedding] {
        guard !texts.isEmpty else { return [] }

        let container = try await modelManager.getModelContainer(id: modelID)

        logger.info("Embed: model=\(modelID), texts=\(texts.count)")

        let embeddings: [MLXContainer_Embedding] = try await container.perform { context in
            // Preferred embedding layer names used by common model families.
            let preferredNames: Set<String> = [
                "embed_tokens",   // LLaMA, Mistral, Gemma
                "wte",            // GPT-2 / GPT-NeoX
                "word_embeddings", // BERT / RoBERTa
                "token_embedding", // generic
            ]

            var embeddingLayer: Embedding? = nil
            var selectedName: String? = nil

            let leafModules = context.model.leafModules().flattened()

            // First pass: look for a layer with one of the preferred names.
            for (name, module) in leafModules {
                if preferredNames.contains(name), let layer = module as? Embedding {
                    embeddingLayer = layer
                    selectedName = name
                    break
                }
            }

            // Second pass: fall back to the first Embedding layer found.
            if embeddingLayer == nil {
                for (name, module) in leafModules {
                    if let layer = module as? Embedding {
                        embeddingLayer = layer
                        selectedName = name
                        break
                    }
                }
            }

            guard let embLayer = embeddingLayer else {
                throw EmbedError.noEmbeddingLayer
            }

            self.logger.info("Embed: using embedding layer '\(selectedName ?? "<unknown>")'")


            var results: [MLXContainer_Embedding] = []
            for text in texts {
                // Tokenize the text.
                let tokenIDs = context.tokenizer.encode(text: text)
                guard !tokenIDs.isEmpty else {
                    results.append(MLXContainer_Embedding(values: []))
                    continue
                }

                // Build an MLXArray of token IDs [seqLen] and look up embeddings [seqLen, dim].
                let tokenArray = MLXArray(tokenIDs.map { Int32($0) })
                let tokenEmbeddings = embLayer(tokenArray)  // [seqLen, dim]

                // Mean-pool over the sequence dimension to get [dim].
                let meanPooled = mean(tokenEmbeddings, axis: 0)  // [dim]

                // L2-normalise so cosine similarity == dot product.
                let norm = sqrt(sum(meanPooled * meanPooled))
                let normalized = meanPooled / (norm + 1e-8)

                // Evaluate before crossing the isolation boundary (MLXArray is not Sendable).
                eval(normalized)

                let floats = normalized.asArray(Float.self)
                results.append(MLXContainer_Embedding(values: floats))
            }
            return results
        }

        logger.info("Embed complete: \(embeddings.count) vectors produced for model \(modelID)")
        return embeddings
    }
}

// MARK: - Inference errors

enum InferenceError: Error, LocalizedError {
    case promptTooLong(length: Int, maxLength: Int)

    var errorDescription: String? {
        switch self {
        case .promptTooLong(let length, let maxLength):
            return "Prompt length \(length) characters exceeds the maximum of \(maxLength) characters"
        }
    }
}

// MARK: - Embed errors

enum EmbedError: Error, LocalizedError {
    case noEmbeddingLayer

    var errorDescription: String? {
        switch self {
        case .noEmbeddingLayer:
            return "Model does not expose a token embedding layer accessible via leafModules()"
        }
    }
}
