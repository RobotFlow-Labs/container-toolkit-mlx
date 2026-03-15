import GRPCCore
import GRPCProtobuf

/// The MLX Container Service namespace.
public enum MLXContainerService {
    public static let descriptor = ServiceDescriptor(fullyQualifiedService: "mlx_container.v1.MLXContainerService")

    // MARK: - Method Descriptors

    public enum Method {
        public enum LoadModel {
            public typealias Input = MLXContainer_LoadModelRequest
            public typealias Output = MLXContainer_LoadModelResponse
            public static let descriptor = MethodDescriptor(
                service: MLXContainerService.descriptor.fullyQualifiedService,
                method: "LoadModel"
            )
        }

        public enum UnloadModel {
            public typealias Input = MLXContainer_UnloadModelRequest
            public typealias Output = MLXContainer_UnloadModelResponse
            public static let descriptor = MethodDescriptor(
                service: MLXContainerService.descriptor.fullyQualifiedService,
                method: "UnloadModel"
            )
        }

        public enum ListModels {
            public typealias Input = MLXContainer_ListModelsRequest
            public typealias Output = MLXContainer_ListModelsResponse
            public static let descriptor = MethodDescriptor(
                service: MLXContainerService.descriptor.fullyQualifiedService,
                method: "ListModels"
            )
        }

        public enum Generate {
            public typealias Input = MLXContainer_GenerateRequest
            public typealias Output = MLXContainer_GenerateResponse
            public static let descriptor = MethodDescriptor(
                service: MLXContainerService.descriptor.fullyQualifiedService,
                method: "Generate"
            )
        }

        public enum Embed {
            public typealias Input = MLXContainer_EmbedRequest
            public typealias Output = MLXContainer_EmbedResponse
            public static let descriptor = MethodDescriptor(
                service: MLXContainerService.descriptor.fullyQualifiedService,
                method: "Embed"
            )
        }

        public enum GetGPUStatus {
            public typealias Input = MLXContainer_GetGPUStatusRequest
            public typealias Output = MLXContainer_GetGPUStatusResponse
            public static let descriptor = MethodDescriptor(
                service: MLXContainerService.descriptor.fullyQualifiedService,
                method: "GetGPUStatus"
            )
        }

        public enum Ping {
            public typealias Input = MLXContainer_PingRequest
            public typealias Output = MLXContainer_PingResponse
            public static let descriptor = MethodDescriptor(
                service: MLXContainerService.descriptor.fullyQualifiedService,
                method: "Ping"
            )
        }
    }
}

// MARK: - Server Protocol

/// Protocol for implementing the MLX Container Service server.
public protocol MLXContainerServiceProtocol: RegistrableRPCService {
    func loadModel(request: ServerRequest<MLXContainer_LoadModelRequest>) async throws -> ServerResponse<MLXContainer_LoadModelResponse>
    func unloadModel(request: ServerRequest<MLXContainer_UnloadModelRequest>) async throws -> ServerResponse<MLXContainer_UnloadModelResponse>
    func listModels(request: ServerRequest<MLXContainer_ListModelsRequest>) async throws -> ServerResponse<MLXContainer_ListModelsResponse>
    func generate(request: ServerRequest<MLXContainer_GenerateRequest>) async throws -> ServerResponse.Stream<MLXContainer_GenerateResponse>
    func embed(request: ServerRequest<MLXContainer_EmbedRequest>) async throws -> ServerResponse<MLXContainer_EmbedResponse>
    func getGPUStatus(request: ServerRequest<MLXContainer_GetGPUStatusRequest>) async throws -> ServerResponse<MLXContainer_GetGPUStatusResponse>
    func ping(request: ServerRequest<MLXContainer_PingRequest>) async throws -> ServerResponse<MLXContainer_PingResponse>
}

extension MLXContainerServiceProtocol {
    public func registerMethods(with router: inout RPCRouter) {
        router.registerHandler(
            forMethod: MLXContainerService.Method.LoadModel.descriptor,
            deserializer: ProtobufDeserializer<MLXContainer_LoadModelRequest>(),
            serializer: ProtobufSerializer<MLXContainer_LoadModelResponse>(),
            handler: { request in
                try await self.loadModel(request: request)
            }
        )

        router.registerHandler(
            forMethod: MLXContainerService.Method.UnloadModel.descriptor,
            deserializer: ProtobufDeserializer<MLXContainer_UnloadModelRequest>(),
            serializer: ProtobufSerializer<MLXContainer_UnloadModelResponse>(),
            handler: { request in
                try await self.unloadModel(request: request)
            }
        )

        router.registerHandler(
            forMethod: MLXContainerService.Method.ListModels.descriptor,
            deserializer: ProtobufDeserializer<MLXContainer_ListModelsRequest>(),
            serializer: ProtobufSerializer<MLXContainer_ListModelsResponse>(),
            handler: { request in
                try await self.listModels(request: request)
            }
        )

        router.registerHandler(
            forMethod: MLXContainerService.Method.Generate.descriptor,
            deserializer: ProtobufDeserializer<MLXContainer_GenerateRequest>(),
            serializer: ProtobufSerializer<MLXContainer_GenerateResponse>(),
            handler: { request in
                try await self.generate(request: request)
            }
        )

        router.registerHandler(
            forMethod: MLXContainerService.Method.Embed.descriptor,
            deserializer: ProtobufDeserializer<MLXContainer_EmbedRequest>(),
            serializer: ProtobufSerializer<MLXContainer_EmbedResponse>(),
            handler: { request in
                try await self.embed(request: request)
            }
        )

        router.registerHandler(
            forMethod: MLXContainerService.Method.GetGPUStatus.descriptor,
            deserializer: ProtobufDeserializer<MLXContainer_GetGPUStatusRequest>(),
            serializer: ProtobufSerializer<MLXContainer_GetGPUStatusResponse>(),
            handler: { request in
                try await self.getGPUStatus(request: request)
            }
        )

        router.registerHandler(
            forMethod: MLXContainerService.Method.Ping.descriptor,
            deserializer: ProtobufDeserializer<MLXContainer_PingRequest>(),
            serializer: ProtobufSerializer<MLXContainer_PingResponse>(),
            handler: { request in
                try await self.ping(request: request)
            }
        )
    }
}
