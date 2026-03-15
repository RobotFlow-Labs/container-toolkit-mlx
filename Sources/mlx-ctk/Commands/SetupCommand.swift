import ArgumentParser
import Foundation
import MLXDeviceDiscovery
import MLXContainerConfig

struct SetupCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "setup",
        abstract: "Validate environment and initialize toolkit"
    )

    @Flag(name: .long, help: "Only check requirements without creating files")
    var checkOnly = false

    func run() async throws {
        print("MLX Container Toolkit — Environment Setup")
        print(String(repeating: "=", count: 50))

        var allPassed = true

        // Check 1: Apple Silicon
        print("\n[1/4] Checking Apple Silicon...")
        let devices = DeviceDiscovery.discover()
        if devices.isEmpty {
            print("  FAIL: No Apple GPU found. Apple Silicon required.")
            allPassed = false
        } else {
            let device = devices[0]
            print("  OK: \(device.name)")
        }

        // Check 2: Metal support
        print("\n[2/4] Checking Metal support...")
        if let device = devices.first {
            if device.supportsMetal3 {
                print("  OK: Metal 3 supported")
            } else {
                print("  OK: Metal supported (family: \(device.gpuFamily))")
            }
        } else {
            print("  FAIL: No Metal support")
            allPassed = false
        }

        // Check 3: Memory
        print("\n[3/4] Checking system memory...")
        let memBytes = DeviceDiscovery.systemMemoryBytes()
        let memGB = Double(memBytes) / (1024 * 1024 * 1024)
        if memGB >= 8 {
            print("  OK: \(String(format: "%.0f", memGB)) GB unified memory")
        } else {
            print("  WARN: \(String(format: "%.0f", memGB)) GB — at least 8 GB recommended")
        }

        // Check 4: container CLI
        print("\n[4/4] Checking Apple container CLI...")
        let containerAvailable = FileManager.default.isExecutableFile(atPath: "/usr/local/bin/container")
            || (try? shellOutput("which container")) != nil
        if containerAvailable {
            print("  OK: container CLI found")
        } else {
            print("  WARN: container CLI not found (optional, needed for Phase 4)")
        }

        print("\n" + String(repeating: "=", count: 50))

        if !checkOnly && allPassed {
            print("\nInitializing toolkit configuration...")
            let config = ToolkitConfiguration()
            let configPath = ToolkitConfiguration.defaultConfigPath
            if !FileManager.default.fileExists(atPath: configPath.path) {
                try config.save()
                print("  Created: \(configPath.path)")
            } else {
                print("  Config already exists: \(configPath.path)")
            }

            let modelsDir = config.resolvedModelsDirectory
            try FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)
            print("  Models directory: \(modelsDir.path)")
        }

        if allPassed {
            print("\nSetup complete! Run 'mlx-ctk device list' to see GPU info.")
        } else {
            print("\nSome checks failed. Please resolve issues above.")
            throw ExitCode.failure
        }
    }

    private func shellOutput(_ command: String) throws -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
