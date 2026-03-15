import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import Logging
import MLXContainerConfig
import MLXContainerProtocol
import MLXDeviceDiscovery

/// The main gRPC inference server that binds to vsock and serves MLX inference requests.
/// Follows the same pattern as Apple's vminitd Server.swift.
public final class MLXInferenceServer: Sendable {
    let config: ToolkitConfiguration
    let gpu: AppleGPUDevice
    let logger: Logger
    public let modelManager: ModelManager
    let gpuMemoryAllocator: GPUMemoryAllocator
    let inferenceEngine: InferenceEngine
    let startTime: Date

    public init(config: ToolkitConfiguration, gpu: AppleGPUDevice, logger: Logger) {
        self.config = config
        self.gpu = gpu
        self.logger = logger
        self.startTime = Date()
        self.gpuMemoryAllocator = GPUMemoryAllocator(
            totalMemoryBytes: gpu.unifiedMemoryBytes,
            maxBudgetBytes: config.maxGPUMemoryBytes,
            logger: logger
        )
        self.modelManager = ModelManager(
            modelsDirectory: config.resolvedModelsDirectory,
            maxLoadedModels: config.maxLoadedModels,
            memoryAllocator: gpuMemoryAllocator,
            logger: logger
        )
        self.inferenceEngine = InferenceEngine(
            modelManager: modelManager,
            defaultMaxTokens: config.defaultMaxTokens,
            defaultTemperature: config.defaultTemperature,
            logger: logger
        )
    }

    /// Start the gRPC server on vsock — blocks until shutdown.
    public func serve() async throws {
        let serviceImpl = MLXContainerServiceImpl(server: self)

        let server = GRPCServer(
            transport: .http2NIOPosix(
                address: .vsock(contextID: .any, port: .init(rawValue: config.vsockPort)),
                transportSecurity: .plaintext
            ),
            services: [serviceImpl]
        )

        logger.info("MLX Container Daemon v0.1.0 listening on vsock port \(config.vsockPort)")
        try await server.serve()
    }

    /// Start the gRPC server on TCP (for local development/testing).
    public func serveTCP(port: Int) async throws {
        let serviceImpl = MLXContainerServiceImpl(server: self)

        let server = GRPCServer(
            transport: .http2NIOPosix(
                address: .ipv4(host: "127.0.0.1", port: port),
                transportSecurity: .plaintext
            ),
            services: [serviceImpl]
        )

        logger.info("MLX Container Daemon v0.1.0 listening on TCP 127.0.0.1:\(port)")
        try await server.serve()
    }
}

/// gRPC service implementation that delegates to the server components.
struct MLXContainerServiceImpl: MLXContainerServiceProtocol {
    let server: MLXInferenceServer

    func loadModel(
        request: MLXContainer_LoadModelRequest,
        context: ServerContext
    ) async throws -> MLXContainer_LoadModelResponse {
        server.logger.info("LoadModel: \(request.modelID)")

        var response = MLXContainer_LoadModelResponse()
        let startTime = Date()

        do {
            try await server.modelManager.loadModel(id: request.modelID, alias: request.alias)
            response.success = true
            response.modelID = request.modelID
            response.loadTimeSeconds = Date().timeIntervalSince(startTime)
            server.logger.info("Model loaded: \(request.modelID) in \(String(format: "%.2f", response.loadTimeSeconds))s")
        } catch {
            response.success = false
            response.error = error.localizedDescription
            server.logger.error("Failed to load model: \(error)")
        }

        return response
    }

    func unloadModel(
        request: MLXContainer_UnloadModelRequest,
        context: ServerContext
    ) async throws -> MLXContainer_UnloadModelResponse {
        server.logger.info("UnloadModel: \(request.modelID)")

        var response = MLXContainer_UnloadModelResponse()
        do {
            try await server.modelManager.unloadModel(id: request.modelID)
            response.success = true
        } catch {
            response.success = false
            response.error = error.localizedDescription
            server.logger.error("Failed to unload model: \(error)")
        }

        return response
    }

    func listModels(
        request: MLXContainer_ListModelsRequest,
        context: ServerContext
    ) async throws -> MLXContainer_ListModelsResponse {
        let models = await server.modelManager.listModels()
        var response = MLXContainer_ListModelsResponse()
        response.models = models.map { model in
            MLXContainer_ModelInfo(
                modelID: model.id,
                alias: model.alias,
                memoryUsedBytes: model.memoryUsedBytes,
                isLoaded: model.isLoaded,
                modelType: model.modelType
            )
        }
        return response
    }

    func generate(
        request: MLXContainer_GenerateRequest,
        context: ServerContext,
        responseWriter: RPCWriter<MLXContainer_GenerateResponse>
    ) async throws {
        server.logger.info("Generate: model=\(request.modelID), prompt_len=\(request.prompt.count)")

        try await server.inferenceEngine.generate(
            modelID: request.modelID,
            prompt: request.prompt,
            messages: request.messages,
            parameters: request.parameters
        ) { token in
            try await responseWriter.write(MLXContainer_GenerateResponse(token: token))
        } onComplete: { complete in
            try await responseWriter.write(MLXContainer_GenerateResponse(complete: complete))
        }
    }

    func embed(
        request: MLXContainer_EmbedRequest,
        context: ServerContext
    ) async throws -> MLXContainer_EmbedResponse {
        return MLXContainer_EmbedResponse(error: "Embeddings not yet implemented")
    }

    func getGPUStatus(
        request: MLXContainer_GetGPUStatusRequest,
        context: ServerContext
    ) async throws -> MLXContainer_GetGPUStatusResponse {
        let models = await server.modelManager.listModels()

        let memSnapshot = await server.gpuMemoryAllocator.snapshot()
        return MLXContainer_GetGPUStatusResponse(
            deviceName: server.gpu.name,
            totalMemoryBytes: server.gpu.unifiedMemoryBytes,
            usedMemoryBytes: memSnapshot.allocatedBytes,
            availableMemoryBytes: memSnapshot.availableBytes,
            gpuFamily: server.gpu.gpuFamily,
            loadedModelsCount: Int32(models.filter(\.isLoaded).count),
            loadedModels: models.map { m in
                MLXContainer_ModelInfo(
                    modelID: m.id,
                    alias: m.alias,
                    memoryUsedBytes: m.memoryUsedBytes,
                    isLoaded: m.isLoaded,
                    modelType: m.modelType
                )
            }
        )
    }

    func ping(
        request: MLXContainer_PingRequest,
        context: ServerContext
    ) async throws -> MLXContainer_PingResponse {
        return MLXContainer_PingResponse(
            status: "ok",
            version: "0.1.0",
            uptimeSeconds: Date().timeIntervalSince(server.startTime)
        )
    }
}
