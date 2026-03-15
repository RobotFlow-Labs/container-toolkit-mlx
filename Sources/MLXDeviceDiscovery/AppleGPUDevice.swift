import Foundation

/// Represents a discovered Apple GPU device with its capabilities.
public struct AppleGPUDevice: Sendable, Codable, CustomStringConvertible {
    /// Human-readable device name (e.g. "Apple M2 Max")
    public let name: String

    /// Metal device registry ID
    public let registryID: UInt64

    /// Recommended maximum working set size in bytes
    public let recommendedMaxWorkingSetSize: UInt64

    /// GPU family string (e.g. "apple9", "metal3")
    public let gpuFamily: String

    /// Total unified memory in bytes (system-wide)
    public let unifiedMemoryBytes: UInt64

    /// Maximum threads per threadgroup
    public let maxThreadsPerThreadgroup: Int

    /// Whether the device supports Metal 3
    public let supportsMetal3: Bool

    /// Whether the device has unified memory architecture
    public let hasUnifiedMemory: Bool

    public init(
        name: String,
        registryID: UInt64,
        recommendedMaxWorkingSetSize: UInt64,
        gpuFamily: String,
        unifiedMemoryBytes: UInt64,
        maxThreadsPerThreadgroup: Int,
        supportsMetal3: Bool,
        hasUnifiedMemory: Bool
    ) {
        self.name = name
        self.registryID = registryID
        self.recommendedMaxWorkingSetSize = recommendedMaxWorkingSetSize
        self.gpuFamily = gpuFamily
        self.unifiedMemoryBytes = unifiedMemoryBytes
        self.maxThreadsPerThreadgroup = maxThreadsPerThreadgroup
        self.supportsMetal3 = supportsMetal3
        self.hasUnifiedMemory = hasUnifiedMemory
    }

    public var description: String {
        let memGB = Double(unifiedMemoryBytes) / (1024 * 1024 * 1024)
        let workingSetGB = Double(recommendedMaxWorkingSetSize) / (1024 * 1024 * 1024)
        return """
        \(name)
          Registry ID:       \(registryID)
          GPU Family:        \(gpuFamily)
          Unified Memory:    \(String(format: "%.1f", memGB)) GB
          Working Set:       \(String(format: "%.1f", workingSetGB)) GB
          Metal 3:           \(supportsMetal3 ? "Yes" : "No")
          Unified Memory:    \(hasUnifiedMemory ? "Yes" : "No")
          Max Threads/Group: \(maxThreadsPerThreadgroup)
        """
    }
}
