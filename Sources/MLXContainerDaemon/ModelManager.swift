import Foundation
import Logging
import MLX
import MLXLLM
import MLXLMCommon

/// Manages MLX model lifecycle — loading, unloading, caching.
public actor ModelManager {
    let modelsDirectory: URL
    let maxLoadedModels: Int
    let memoryAllocator: GPUMemoryAllocator
    let logger: Logger

    private var loadedModels: [String: LoadedModel] = [:]

    public struct ModelEntry: Sendable {
        public let id: String
        public let isLoaded: Bool
        public let modelType: String
    }

    struct LoadedModel {
        let id: String
        let container: ModelContainer
        let loadedAt: Date
    }

    public init(
        modelsDirectory: URL,
        maxLoadedModels: Int,
        memoryAllocator: GPUMemoryAllocator,
        logger: Logger
    ) {
        self.modelsDirectory = modelsDirectory
        self.maxLoadedModels = maxLoadedModels
        self.memoryAllocator = memoryAllocator
        self.logger = logger
    }

    /// Load a model by HuggingFace ID (e.g. "mlx-community/Llama-3.2-1B-4bit").
    public func loadModel(id modelID: String) async throws {
        if loadedModels[modelID] != nil {
            logger.info("Model already loaded: \(modelID)")
            return
        }

        // Evict oldest model if at capacity
        if loadedModels.count >= maxLoadedModels {
            let oldest = loadedModels.min(by: { $0.value.loadedAt < $1.value.loadedAt })
            if let oldest {
                logger.info("Evicting model to make room: \(oldest.key)")
                loadedModels.removeValue(forKey: oldest.key)
            }
        }

        logger.info("Loading model: \(modelID)")

        let modelConfig = ModelConfiguration(id: modelID)
        let container = try await LLMModelFactory.shared.loadContainer(
            configuration: modelConfig
        ) { progress in
            self.logger.debug("Download progress: \(Int(progress.fractionCompleted * 100))%")
        }

        loadedModels[modelID] = LoadedModel(
            id: modelID,
            container: container,
            loadedAt: Date()
        )

        logger.info("Model loaded successfully: \(modelID)")
    }

    /// Unload a model and free its resources.
    public func unloadModel(id modelID: String) throws {
        guard loadedModels.removeValue(forKey: modelID) != nil else {
            throw ModelManagerError.modelNotLoaded(modelID)
        }
        logger.info("Model unloaded: \(modelID)")
    }

    /// Get the ModelContainer for a loaded model.
    public func getModelContainer(id modelID: String) throws -> ModelContainer {
        guard let model = loadedModels[modelID] else {
            throw ModelManagerError.modelNotLoaded(modelID)
        }
        return model.container
    }

    /// List all tracked models.
    public func listModels() -> [ModelEntry] {
        loadedModels.map { (id, model) in
            ModelEntry(id: id, isLoaded: true, modelType: "llm")
        }
    }
}

enum ModelManagerError: Error, LocalizedError {
    case modelNotLoaded(String)
    case modelLoadFailed(String, Error)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded(let id):
            return "Model not loaded: \(id)"
        case .modelLoadFailed(let id, let error):
            return "Failed to load model \(id): \(error.localizedDescription)"
        }
    }
}
