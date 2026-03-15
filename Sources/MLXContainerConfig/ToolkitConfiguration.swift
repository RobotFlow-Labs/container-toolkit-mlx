import Foundation
import Logging

/// Global configuration for the MLX Container Toolkit daemon.
public struct ToolkitConfiguration: Sendable, Codable {
    /// vsock port for the gRPC daemon (default: 2048)
    public var vsockPort: UInt32

    /// Directory for cached MLX models
    public var modelsDirectory: String

    /// Maximum GPU memory budget in bytes (0 = unlimited)
    public var maxGPUMemoryBytes: UInt64

    /// Maximum number of concurrent models loaded
    public var maxLoadedModels: Int

    /// Log level string
    public var logLevel: String

    /// Whether to enable streaming responses
    public var enableStreaming: Bool

    /// Default generation parameters
    public var defaultMaxTokens: Int
    public var defaultTemperature: Float

    public static let defaultVsockPort: UInt32 = 2048
    public static let defaultModelsDirectory = "~/.mlx-container/models"

    public init(
        vsockPort: UInt32 = Self.defaultVsockPort,
        modelsDirectory: String = Self.defaultModelsDirectory,
        maxGPUMemoryBytes: UInt64 = 0,
        maxLoadedModels: Int = 3,
        logLevel: String = "info",
        enableStreaming: Bool = true,
        defaultMaxTokens: Int = 512,
        defaultTemperature: Float = 0.7
    ) {
        self.vsockPort = vsockPort
        self.modelsDirectory = modelsDirectory
        self.maxGPUMemoryBytes = maxGPUMemoryBytes
        self.maxLoadedModels = maxLoadedModels
        self.logLevel = logLevel
        self.enableStreaming = enableStreaming
        self.defaultMaxTokens = defaultMaxTokens
        self.defaultTemperature = defaultTemperature
    }

    /// Resolved models directory path (expands ~)
    public var resolvedModelsDirectory: URL {
        URL(fileURLWithPath: NSString(string: modelsDirectory).expandingTildeInPath)
    }

    /// Default config file path
    public static var defaultConfigPath: URL {
        URL(fileURLWithPath: NSString(string: "~/.mlx-container/config.json").expandingTildeInPath)
    }

    /// Load configuration from a JSON file.
    public static func load(from path: URL? = nil) throws -> ToolkitConfiguration {
        let configPath = path ?? defaultConfigPath
        guard FileManager.default.fileExists(atPath: configPath.path) else {
            return ToolkitConfiguration()
        }
        let data = try Data(contentsOf: configPath)
        return try JSONDecoder().decode(ToolkitConfiguration.self, from: data)
    }

    /// Save configuration to a JSON file.
    public func save(to path: URL? = nil) throws {
        let configPath = path ?? Self.defaultConfigPath
        let dir = configPath.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: configPath, options: .atomic)
    }
}
