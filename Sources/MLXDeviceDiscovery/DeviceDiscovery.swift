#if canImport(Metal)
import Metal
#endif
import Foundation
import Logging

/// Discovers Apple GPU devices and their capabilities via the Metal framework.
public struct DeviceDiscovery: Sendable {
    private static let logger = Logger(label: "com.aiflowlabs.mlx-ctk.device-discovery")

    /// Discover all available Metal GPU devices.
    public static func discover() -> [AppleGPUDevice] {
        #if canImport(Metal)
        return discoverMetal()
        #else
        logger.warning("Metal framework not available on this platform")
        return []
        #endif
    }

    /// Get the default (system) GPU device.
    public static func defaultDevice() -> AppleGPUDevice? {
        discover().first
    }

    /// Get total system memory via sysctl.
    public static func systemMemoryBytes() -> UInt64 {
        var size: UInt64 = 0
        var len = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &size, &len, nil, 0)
        return size
    }

    /// Get the Apple Silicon chip name via sysctl (e.g. "Apple M2 Max").
    public static func chipName() -> String? {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        guard size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &buffer, &size, nil, 0)
        return String(cString: buffer)
    }

    #if canImport(Metal)
    private static func discoverMetal() -> [AppleGPUDevice] {
        guard let device = MTLCreateSystemDefaultDevice() else {
            logger.error("No Metal device found")
            return []
        }

        let systemMem = systemMemoryBytes()

        let gpuFamily: String
        if device.supportsFamily(.metal3) {
            gpuFamily = "metal3"
        } else if device.supportsFamily(.apple9) {
            gpuFamily = "apple9"
        } else if device.supportsFamily(.apple8) {
            gpuFamily = "apple8"
        } else if device.supportsFamily(.apple7) {
            gpuFamily = "apple7"
        } else {
            gpuFamily = "apple-unknown"
        }

        let gpu = AppleGPUDevice(
            name: device.name,
            registryID: device.registryID,
            recommendedMaxWorkingSetSize: UInt64(device.recommendedMaxWorkingSetSize),
            gpuFamily: gpuFamily,
            unifiedMemoryBytes: systemMem,
            maxThreadsPerThreadgroup: device.maxThreadsPerThreadgroup.width,
            supportsMetal3: device.supportsFamily(.metal3),
            hasUnifiedMemory: device.hasUnifiedMemory
        )

        logger.info("Discovered GPU: \(gpu.name), memory: \(systemMem / (1024*1024*1024)) GB")
        return [gpu]
    }
    #endif
}
