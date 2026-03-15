import Foundation
import Logging
import MLXContainerConfig

/// Manages the lifecycle of the MLX Container Daemon alongside containers.
/// Starts the daemon when a GPU-enabled container launches, stops when all GPU containers exit.
public actor GPUDaemonLifecycle {
    let config: ToolkitConfiguration
    let logger: Logger

    private var daemonProcess: Process?
    private var activeContainers: Set<String> = []

    public init(config: ToolkitConfiguration, logger: Logger) {
        self.config = config
        self.logger = logger
    }

    /// Start the daemon if not already running, register a container.
    public func startForContainer(containerID: String, gpuConfig: ContainerGPUConfig) async throws {
        activeContainers.insert(containerID)

        if daemonProcess == nil || !(daemonProcess?.isRunning ?? false) {
            try startDaemon(preloadModel: gpuConfig.preloadModel)
        }

        logger.info("GPU daemon active for container \(containerID)")
    }

    /// Unregister a container. Stop daemon if no containers remain.
    public func stopForContainer(containerID: String) async {
        activeContainers.remove(containerID)

        if activeContainers.isEmpty {
            stopDaemon()
        }

        logger.info("Container \(containerID) unregistered from GPU daemon")
    }

    /// Check if the daemon is running.
    public var isRunning: Bool {
        daemonProcess?.isRunning ?? false
    }

    /// Get the number of active GPU containers.
    public var activeContainerCount: Int {
        activeContainers.count
    }

    private func startDaemon(preloadModel: String?) throws {
        let process = Process()

        // Look for the daemon binary
        let daemonPath = Self.findDaemonBinary()
        guard let path = daemonPath else {
            throw GPUDaemonError.daemonNotFound
        }

        process.executableURL = URL(fileURLWithPath: path)
        var arguments = [
            "--port", String(config.vsockPort),
            "--log-level", config.logLevel,
        ]
        if let model = preloadModel {
            arguments += ["--preload-model", model]
        }
        process.arguments = arguments

        // Redirect output to log files
        let logDir = config.resolvedModelsDirectory.deletingLastPathComponent().appendingPathComponent("logs")
        try FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)

        process.standardOutput = try FileHandle(forWritingTo: logDir.appendingPathComponent("daemon.log"))
        process.standardError = try FileHandle(forWritingTo: logDir.appendingPathComponent("daemon-error.log"))

        try process.run()
        daemonProcess = process

        logger.info("MLX Container Daemon started (PID: \(process.processIdentifier))")
    }

    private func stopDaemon() {
        guard let process = daemonProcess, process.isRunning else { return }
        process.terminate()
        daemonProcess = nil
        logger.info("MLX Container Daemon stopped")
    }

    /// Find the daemon binary in standard locations.
    static func findDaemonBinary() -> String? {
        let candidates = [
            "/usr/local/bin/mlx-container-daemon",
            "/opt/homebrew/bin/mlx-container-daemon",
            Bundle.main.bundlePath + "/mlx-container-daemon",
        ]

        // Also check PATH
        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            for dir in pathEnv.split(separator: ":") {
                let candidate = "\(dir)/mlx-container-daemon"
                if FileManager.default.isExecutableFile(atPath: candidate) {
                    return candidate
                }
            }
        }

        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}

enum GPUDaemonError: Error, LocalizedError {
    case daemonNotFound
    case daemonStartFailed(String)

    var errorDescription: String? {
        switch self {
        case .daemonNotFound:
            return "mlx-container-daemon binary not found. Build with: swift build --product mlx-container-daemon"
        case .daemonStartFailed(let reason):
            return "Failed to start GPU daemon: \(reason)"
        }
    }
}
