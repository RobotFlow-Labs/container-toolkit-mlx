import ArgumentParser
import Foundation
import MLXContainerConfig

struct ConfigCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "Manage toolkit configuration",
        subcommands: [ShowConfig.self, SetConfig.self, ResetConfig.self],
        defaultSubcommand: ShowConfig.self
    )

    struct ShowConfig: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "show",
            abstract: "Show current configuration"
        )

        func run() async throws {
            let config = try ToolkitConfiguration.load()
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            print(String(data: data, encoding: .utf8)!)
        }
    }

    struct SetConfig: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "set",
            abstract: "Set a configuration value"
        )

        @Option(name: .long, help: "vsock port for daemon")
        var vsockPort: UInt32?

        @Option(name: .long, help: "Directory for MLX models")
        var modelsDir: String?

        @Option(name: .long, help: "Max GPU memory in GB (0 = unlimited)")
        var maxGPUMemoryGB: UInt64?

        @Option(name: .long, help: "Max number of loaded models")
        var maxModels: Int?

        @Option(name: .long, help: "Default max tokens for generation")
        var defaultMaxTokens: Int?

        @Option(name: .long, help: "Default temperature for generation")
        var defaultTemperature: Float?

        func run() async throws {
            var config = try ToolkitConfiguration.load()

            if let port = vsockPort {
                config.vsockPort = port
            }
            if let dir = modelsDir {
                config.modelsDirectory = dir
            }
            if let mem = maxGPUMemoryGB {
                config.maxGPUMemoryBytes = mem * 1024 * 1024 * 1024
            }
            if let max = maxModels {
                config.maxLoadedModels = max
            }
            if let tokens = defaultMaxTokens {
                config.defaultMaxTokens = tokens
            }
            if let temp = defaultTemperature {
                config.defaultTemperature = temp
            }

            try config.save()
            print("Configuration updated.")
        }
    }

    struct ResetConfig: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "reset",
            abstract: "Reset configuration to defaults"
        )

        func run() async throws {
            let config = ToolkitConfiguration()
            try config.save()
            print("Configuration reset to defaults.")
        }
    }
}
