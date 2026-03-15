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
        public let alias: String
        public let isLoaded: Bool
        public let modelType: String
        public let memoryUsedBytes: UInt64
    }

    struct LoadedModel {
        let id: String
        let alias: String
        let container: ModelContainer
        let loadedAt: Date
        let memoryUsedBytes: UInt64
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
    public func loadModel(id modelID: String, alias: String = "") async throws {
        if loadedModels[modelID] != nil {
            logger.info("Model already loaded: \(modelID)")
            return
        }

        // Evict oldest model if at capacity
        if loadedModels.count >= maxLoadedModels {
            let oldest = loadedModels.min(by: { $0.value.loadedAt < $1.value.loadedAt })
            if let oldest {
                logger.info("Evicting model to make room: \(oldest.key)")
                await memoryAllocator.release(containerID: oldest.key)
                loadedModels.removeValue(forKey: oldest.key)
            }
        }

        logger.info("Loading model: \(modelID) (downloading if needed...)")

        // Snapshot memory before load to measure actual usage
        let memBefore = Memory.snapshot()

        let modelConfig = ModelConfiguration(id: modelID)
        let container = try await LLMModelFactory.shared.loadContainer(
            configuration: modelConfig
        ) { progress in
            if progress.fractionCompleted < 1.0 {
                print("  Downloading: \(Int(progress.fractionCompleted * 100))%", terminator: "\r")
                fflush(stdout)
            }
        }

        // Measure actual active memory delta after loading weights
        let memAfter = Memory.snapshot()
        let deltaBytes = memAfter.activeMemory > memBefore.activeMemory
            ? UInt64(memAfter.activeMemory - memBefore.activeMemory)
            : UInt64(memAfter.activeMemory)
        // Use at least 1 MB as the allocation request so we always register something
        let requestBytes = max(deltaBytes, 1024 * 1024)

        let grantedBytes = try await memoryAllocator.allocate(containerID: modelID, requestedBytes: requestBytes)

        loadedModels[modelID] = LoadedModel(
            id: modelID,
            alias: alias,
            container: container,
            loadedAt: Date(),
            memoryUsedBytes: grantedBytes
        )

        logger.info("Model loaded successfully: \(modelID) (memory: \(grantedBytes / (1024*1024)) MB)")
    }

    /// Unload a model and free its resources.
    public func unloadModel(id modelID: String) async throws {
        guard loadedModels.removeValue(forKey: modelID) != nil else {
            throw ModelManagerError.modelNotLoaded(modelID)
        }
        await memoryAllocator.release(containerID: modelID)
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
            ModelEntry(
                id: id,
                alias: model.alias,
                isLoaded: true,
                modelType: "llm",
                memoryUsedBytes: model.memoryUsedBytes
            )
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
