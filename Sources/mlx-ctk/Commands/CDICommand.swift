import ArgumentParser
import Foundation
import Logging
import MLXDeviceDiscovery
import MLXContainerConfig

struct CDICommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cdi",
        abstract: "Container Device Interface (CDI) spec management",
        subcommands: [Generate.self, List.self],
        defaultSubcommand: Generate.self
    )

    // MARK: - Generate

    struct Generate: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "generate",
            abstract: "Generate a CDI spec for the Apple GPU"
        )

        @Option(name: .long, help: "Output path for the CDI spec (default: ~/.config/cdi/apple.com-gpu.yaml)")
        var output: String?

        @Flag(name: .long, help: "Output JSON instead of YAML")
        var json = false

        private static let defaultCDIPath = "~/.config/cdi/apple.com-gpu.yaml"
        private static let vsockCID: UInt32 = 2
        private static let hookBinaryPath = "/usr/local/bin/mlx-cdi-hook"

        func run() async throws {
            var logger = Logger(label: "com.aiflowlabs.mlx-ctk.cdi")
            logger.logLevel = .info

            let devices = DeviceDiscovery.discover()
            guard let gpu = devices.first else {
                print("Error: No Apple GPU found. Apple Silicon required.")
                throw ExitCode.failure
            }

            // Read vsock port from user config (respects mlx-ctk config set --vsock-port)
            let toolkitConfig = (try? ToolkitConfiguration.load()) ?? ToolkitConfiguration()
            let vsockPort = toolkitConfig.vsockPort

            let outputPath: String
            if let custom = output {
                outputPath = custom
            } else if json {
                // If --json and no explicit output, use a .json extension variant alongside default
                outputPath = Self.defaultCDIPath.replacingOccurrences(of: ".yaml", with: ".json")
            } else {
                outputPath = Self.defaultCDIPath
            }

            let resolvedPath = NSString(string: outputPath).expandingTildeInPath
            let url = URL(fileURLWithPath: resolvedPath)

            // Ensure parent directory exists
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let spec = CDISpec(
                gpu: gpu,
                vsockCID: Self.vsockCID,
                vsockPort: vsockPort,
                hookPath: Self.hookBinaryPath
            )

            let content: String
            if json {
                content = try spec.renderJSON()
            } else {
                content = spec.renderYAML()
            }

            try content.write(to: url, atomically: true, encoding: .utf8)

            logger.info("CDI spec written to \(resolvedPath)")
            print("CDI spec generated: \(resolvedPath)")
            print("Device: \(gpu.name) (\(gpu.gpuFamily))")
            print("vsock CID:\(Self.vsockCID) port:\(vsockPort)")
        }
    }

    // MARK: - List

    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List generated CDI specs"
        )

        @Option(name: .long, help: "CDI config directory (default: ~/.config/cdi)")
        var dir: String = "~/.config/cdi"

        func run() async throws {
            let resolvedDir = NSString(string: dir).expandingTildeInPath
            let dirURL = URL(fileURLWithPath: resolvedDir)

            guard FileManager.default.fileExists(atPath: resolvedDir) else {
                print("CDI directory not found: \(resolvedDir)")
                print("Run 'mlx-ctk cdi generate' to create a spec.")
                return
            }

            let contents = try FileManager.default.contentsOfDirectory(
                at: dirURL,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )

            let specs = contents.filter {
                let ext = $0.pathExtension
                return ext == "yaml" || ext == "yml" || ext == "json"
            }.sorted { $0.lastPathComponent < $1.lastPathComponent }

            if specs.isEmpty {
                print("No CDI specs found in \(resolvedDir)")
                print("Run 'mlx-ctk cdi generate' to create one.")
                return
            }

            print("CDI Specs in \(resolvedDir)")
            print(String(repeating: "-", count: 50))
            for spec in specs {
                let attrs = try spec.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                let size = attrs.fileSize.map { "\($0) bytes" } ?? "unknown size"
                let modified = attrs.contentModificationDate.map { ISO8601DateFormatter().string(from: $0) } ?? "unknown date"
                print("  \(spec.lastPathComponent)  (\(size), modified \(modified))")
            }
        }
    }
}

// MARK: - CDI Spec Model

private struct CDISpec {
    let gpu: AppleGPUDevice
    let vsockCID: UInt32
    let vsockPort: UInt32
    let hookPath: String

    static let cdiVersion = "0.5.0"
    static let cdiKind = "apple.com/gpu"

    func renderYAML() -> String {
        """
        cdiVersion: "\(Self.cdiVersion)"
        kind: "\(Self.cdiKind)"
        devices:
          - name: "0"
            containerEdits:
              env:
                - "MLX_VSOCK_CID=\(vsockCID)"
                - "MLX_VSOCK_PORT=\(vsockPort)"
                - "MLX_GPU_DEVICE=\(gpu.name)"
                - "MLX_GPU_FAMILY=\(gpu.gpuFamily)"
                - "MLX_GPU_MEMORY=\(gpu.unifiedMemoryBytes)"
              hooks:
                - hookName: "startContainer"
                  path: "\(hookPath)"
                  args: ["mlx-cdi-hook", "start-daemon"]
        """
    }

    func renderJSON() throws -> String {
        let spec: [String: Any] = [
            "cdiVersion": Self.cdiVersion,
            "kind": Self.cdiKind,
            "devices": [
                [
                    "name": "0",
                    "containerEdits": [
                        "env": [
                            "MLX_VSOCK_CID=\(vsockCID)",
                            "MLX_VSOCK_PORT=\(vsockPort)",
                            "MLX_GPU_DEVICE=\(gpu.name)",
                            "MLX_GPU_FAMILY=\(gpu.gpuFamily)",
                            "MLX_GPU_MEMORY=\(gpu.unifiedMemoryBytes)",
                        ],
                        "hooks": [
                            [
                                "hookName": "startContainer",
                                "path": hookPath,
                                "args": ["mlx-cdi-hook", "start-daemon"],
                            ]
                        ],
                    ],
                ]
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: spec, options: [.prettyPrinted, .sortedKeys])
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
