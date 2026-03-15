import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import GRPCProtobuf
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
                address: .vsock(contextID: .any, port: .init(config.vsockPort)),
                transportSecurity: .plaintext
            ),
            services: [serviceImpl]
        )

        logger.info("MLX Container Daemon v0.1.0 listening on vsock port \(config.vsockPort)")
        try await server.serve()
    }
}

/// gRPC service implementation that delegates to the server components.
struct MLXContainerServiceImpl: MLXContainerServiceProtocol {
    let server: MLXInferenceServer

    func loadModel(request: ServerRequest<MLXContainer_LoadModelRequest>) async throws -> ServerResponse<MLXContainer_LoadModelResponse> {
        let req = request.message
        server.logger.info("LoadModel: \(req.modelID)")

        var response = MLXContainer_LoadModelResponse()
        let startTime = Date()

        do {
            try await server.modelManager.loadModel(id: req.modelID)
            response.success = true
            response.modelID = req.modelID
            response.loadTimeSeconds = Date().timeIntervalSince(startTime)
            server.logger.info("Model loaded: \(req.modelID) in \(String(format: "%.2f", response.loadTimeSeconds))s")
        } catch {
            response.success = false
            response.error = error.localizedDescription
            server.logger.error("Failed to load model: \(error)")
        }

        return ServerResponse(message: response)
    }

    func unloadModel(request: ServerRequest<MLXContainer_UnloadModelRequest>) async throws -> ServerResponse<MLXContainer_UnloadModelResponse> {
        let req = request.message
        server.logger.info("UnloadModel: \(req.modelID)")

        var response = MLXContainer_UnloadModelResponse()
        do {
            try await server.modelManager.unloadModel(id: req.modelID)
            response.success = true
        } catch {
            response.success = false
            response.error = error.localizedDescription
        }

        return ServerResponse(message: response)
    }

    func listModels(request: ServerRequest<MLXContainer_ListModelsRequest>) async throws -> ServerResponse<MLXContainer_ListModelsResponse> {
        let models = await server.modelManager.listModels()
        var response = MLXContainer_ListModelsResponse()
        response.models = models.map { model in
            var info = MLXContainer_ModelInfo()
            info.modelID = model.id
            info.isLoaded = model.isLoaded
            info.modelType = model.modelType
            return info
        }
        return ServerResponse(message: response)
    }

    func generate(request: ServerRequest<MLXContainer_GenerateRequest>) async throws -> ServerResponse.Stream<MLXContainer_GenerateResponse> {
        let req = request.message
        server.logger.info("Generate: model=\(req.modelID), prompt_len=\(req.prompt.count)")

        return ServerResponse.Stream(of: MLXContainer_GenerateResponse.self) { writer in
            do {
                try await server.inferenceEngine.generate(
                    modelID: req.modelID,
                    prompt: req.prompt,
                    messages: req.messages,
                    parameters: req.parameters
                ) { token in
                    let response = MLXContainer_GenerateResponse(token: token)
                    try await writer.write(response)
                } onComplete: { complete in
                    let response = MLXContainer_GenerateResponse(complete: complete)
                    try await writer.write(response)
                }
            } catch {
                server.logger.error("Generate error: \(error)")
                throw error
            }
        }
    }

    func embed(request: ServerRequest<MLXContainer_EmbedRequest>) async throws -> ServerResponse<MLXContainer_EmbedResponse> {
        var response = MLXContainer_EmbedResponse()
        response.error = "Embeddings not yet implemented"
        return ServerResponse(message: response)
    }

    func getGPUStatus(request: ServerRequest<MLXContainer_GetGPUStatusRequest>) async throws -> ServerResponse<MLXContainer_GetGPUStatusResponse> {
        let models = await server.modelManager.listModels()

        var response = MLXContainer_GetGPUStatusResponse()
        response.deviceName = server.gpu.name
        response.totalMemoryBytes = server.gpu.unifiedMemoryBytes
        response.gpuFamily = server.gpu.gpuFamily
        response.loadedModelsCount = Int32(models.filter(\.isLoaded).count)
        response.loadedModels = models.map { m in
            var info = MLXContainer_ModelInfo()
            info.modelID = m.id
            info.isLoaded = m.isLoaded
            info.modelType = m.modelType
            return info
        }
        return ServerResponse(message: response)
    }

    func ping(request: ServerRequest<MLXContainer_PingRequest>) async throws -> ServerResponse<MLXContainer_PingResponse> {
        var response = MLXContainer_PingResponse()
        response.status = "ok"
        response.version = "0.1.0"
        response.uptimeSeconds = Date().timeIntervalSince(server.startTime)
        return ServerResponse(message: response)
    }
}
