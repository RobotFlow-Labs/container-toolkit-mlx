import ArgumentParser
import Foundation
import MLXDeviceDiscovery

struct DeviceCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "device",
        abstract: "GPU device discovery and information",
        subcommands: [ListDevices.self],
        defaultSubcommand: ListDevices.self
    )

    struct ListDevices: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List available Apple GPU devices"
        )

        @Flag(name: .long, help: "Output as JSON")
        var json = false

        func run() async throws {
            let devices = DeviceDiscovery.discover()

            if devices.isEmpty {
                print("No Metal GPU devices found.")
                print("This tool requires Apple Silicon (M1/M2/M3/M4).")
                throw ExitCode.failure
            }

            if json {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(devices)
                print(String(data: data, encoding: .utf8)!)
            } else {
                print("Apple GPU Devices")
                print(String(repeating: "=", count: 50))
                for (i, device) in devices.enumerated() {
                    print("\nDevice \(i):")
                    print(device)
                }
                print(String(repeating: "=", count: 50))

                if let chip = DeviceDiscovery.chipName() {
                    print("Chip: \(chip)")
                }
                let sysMem = DeviceDiscovery.systemMemoryBytes()
                let sysMemGB = Double(sysMem) / (1024 * 1024 * 1024)
                print("System Memory: \(String(format: "%.1f", sysMemGB)) GB")
            }
        }
    }
}
