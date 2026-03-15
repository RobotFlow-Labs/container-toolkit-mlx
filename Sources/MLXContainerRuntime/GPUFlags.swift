import Foundation

/// GPU-related command-line flags for `container run --gpu`.
/// Designed to integrate with Apple's container CLI flag system.
///
/// Usage:
///   container run --gpu --gpu-memory 8 --gpu-model mlx-community/Llama-3.2-1B-4bit ...
///
/// This struct mirrors the pattern from apple-container's Flags.swift.
public struct GPUFlags: Sendable, Codable {
    /// Enable GPU access for the container
    public var gpu: Bool

    /// GPU memory budget in GB (0 = share)
    public var gpuMemory: UInt64

    /// Model to pre-load when container starts
    public var gpuModel: String?

    /// Maximum tokens per request
    public var gpuMaxTokens: Int

    /// Allow the container to load/unload models
    public var gpuModelManagement: Bool

    /// Custom vsock port for the GPU daemon
    public var gpuPort: UInt32

    public init(
        gpu: Bool = false,
        gpuMemory: UInt64 = 0,
        gpuModel: String? = nil,
        gpuMaxTokens: Int = 2048,
        gpuModelManagement: Bool = true,
        gpuPort: UInt32 = 2048
    ) {
        self.gpu = gpu
        self.gpuMemory = gpuMemory
        self.gpuModel = gpuModel
        self.gpuMaxTokens = gpuMaxTokens
        self.gpuModelManagement = gpuModelManagement
        self.gpuPort = gpuPort
    }
}

// MARK: - Integration Example
//
// To add these flags to apple/container's CLI, add to Flags.swift:
//
// ```swift
// public struct GPU: ParsableArguments {
//     public init() {}
//
//     @Flag(name: .long, help: "Enable GPU access via MLX Container Toolkit")
//     public var gpu: Bool = false
//
//     @Option(name: .customLong("gpu-memory"), help: "GPU memory budget in GB (0 = share)")
//     public var gpuMemory: UInt64 = 0
//
//     @Option(name: .customLong("gpu-model"), help: "Model to pre-load")
//     public var gpuModel: String?
//
//     @Option(name: .customLong("gpu-max-tokens"), help: "Max tokens per request")
//     public var gpuMaxTokens: Int = 2048
//
//     @Flag(name: .customLong("gpu-model-management"), help: "Allow container to manage models")
//     public var gpuModelManagement: Bool = true
//
//     @Option(name: .customLong("gpu-port"), help: "vsock port for GPU daemon")
//     public var gpuPort: UInt32 = 2048
// }
// ```
//
// Then in ContainerRun.swift:
//
// ```swift
// @OptionGroup(title: "GPU options")
// var gpuFlags: Flags.GPU
// ```
