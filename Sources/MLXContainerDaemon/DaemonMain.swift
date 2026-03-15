import ArgumentParser
import Foundation
import Logging
import MLXContainerConfig
import MLXDeviceDiscovery

@main
struct DaemonMain: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mlx-container-daemon",
        abstract: "MLX Container GPU Daemon — serves inference over vsock to Linux containers"
    )

    @Option(name: .long, help: "vsock port to listen on")
    var port: UInt32?

    @Option(name: .long, help: "Path to config file")
    var config: String?

    @Option(name: .long, help: "Log level (trace, debug, info, warning, error)")
    var logLevel: String = "info"

    @Option(name: .long, help: "Model to pre-load on startup")
    var preloadModel: String?

    func run() async throws {
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardError(label: label)
            handler.logLevel = Logger.Level(rawValue: logLevel) ?? .info
            return handler
        }
        let logger = Logger(label: "com.aiflowlabs.mlx-container-daemon")

        // Load config
        let configPath = config.map { URL(fileURLWithPath: $0) }
        var toolkitConfig = try ToolkitConfiguration.load(from: configPath)
        if let p = port {
            toolkitConfig.vsockPort = p
        }

        // Discover GPU
        let devices = DeviceDiscovery.discover()
        guard let gpu = devices.first else {
            logger.critical("No Apple GPU found. Cannot start daemon.")
            throw ExitCode.failure
        }
        logger.info("GPU: \(gpu.name), Memory: \(gpu.unifiedMemoryBytes / (1024*1024*1024)) GB")

        // Create and start the inference server
        let server = MLXInferenceServer(
            config: toolkitConfig,
            gpu: gpu,
            logger: logger
        )

        // Pre-load model if requested
        if let modelID = preloadModel {
            logger.info("Pre-loading model: \(modelID)")
            try await server.modelManager.loadModel(id: modelID)
        }

        logger.info("Starting gRPC server on vsock port \(toolkitConfig.vsockPort)")
        try await server.serve()
    }
}
