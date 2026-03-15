import ArgumentParser
import Foundation

@main
struct MLXContainerToolkit: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mlx-ctk",
        abstract: "Apple Container MLX Toolkit — GPU-accelerated ML inference for Linux containers on Apple Silicon",
        version: "0.1.0",
        subcommands: [
            DeviceCommand.self,
            SetupCommand.self,
            ConfigCommand.self,
        ],
        defaultSubcommand: nil
    )
}
