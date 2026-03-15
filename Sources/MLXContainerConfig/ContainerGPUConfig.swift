import Foundation

/// Per-container GPU configuration.
public struct ContainerGPUConfig: Sendable, Codable {
    /// Whether GPU access is enabled for this container
    public var enabled: Bool

    /// GPU memory budget for this container in bytes (0 = share with others)
    public var memoryBudgetBytes: UInt64

    /// Model to pre-load when the container starts
    public var preloadModel: String?

    /// Maximum tokens per request for this container
    public var maxTokensPerRequest: Int

    /// Whether this container can load/unload models (vs. using pre-loaded only)
    public var allowModelManagement: Bool

    /// Container identifier for tracking GPU allocations
    public var containerID: String?

    public init(
        enabled: Bool = true,
        memoryBudgetBytes: UInt64 = 0,
        preloadModel: String? = nil,
        maxTokensPerRequest: Int = 2048,
        allowModelManagement: Bool = true,
        containerID: String? = nil
    ) {
        self.enabled = enabled
        self.memoryBudgetBytes = memoryBudgetBytes
        self.preloadModel = preloadModel
        self.maxTokensPerRequest = maxTokensPerRequest
        self.allowModelManagement = allowModelManagement
        self.containerID = containerID
    }

    /// A disabled GPU config (GPU access off)
    public static let disabled = ContainerGPUConfig(enabled: false)
}
