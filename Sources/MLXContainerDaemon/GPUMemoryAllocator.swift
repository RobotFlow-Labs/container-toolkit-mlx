import Foundation
import Logging
import MLX

/// Manages GPU memory budgets per container.
public actor GPUMemoryAllocator {
    let totalMemoryBytes: UInt64
    let maxBudgetBytes: UInt64
    let logger: Logger

    private var allocations: [String: UInt64] = [:]

    public init(totalMemoryBytes: UInt64, maxBudgetBytes: UInt64, logger: Logger) {
        self.totalMemoryBytes = totalMemoryBytes
        self.maxBudgetBytes = maxBudgetBytes > 0 ? maxBudgetBytes : totalMemoryBytes
        self.logger = logger
    }

    /// Request a memory allocation for a container.
    public func allocate(containerID: String, requestedBytes: UInt64) throws -> UInt64 {
        // Subtract existing allocation for this container so re-allocation
        // doesn't double-count against the budget.
        let existingBytes = allocations[containerID] ?? 0
        let currentUsed = allocations.values.reduce(0, +) - existingBytes
        let available = currentUsed < maxBudgetBytes ? maxBudgetBytes - currentUsed : 0

        let grantedBytes = min(requestedBytes, available)
        guard grantedBytes > 0 else {
            throw GPUMemoryError.insufficientMemory(
                requested: requestedBytes,
                available: available
            )
        }

        allocations[containerID] = grantedBytes
        logger.info("GPU memory allocated: \(grantedBytes / (1024*1024)) MB for container \(containerID)")
        return grantedBytes
    }

    /// Release memory allocation for a container.
    public func release(containerID: String) {
        let freed = allocations.removeValue(forKey: containerID) ?? 0
        if freed > 0 {
            logger.info("GPU memory released: \(freed / (1024*1024)) MB for container \(containerID)")
        }
    }

    /// Get current memory snapshot.
    public func snapshot() -> MemorySnapshot {
        let allocated = allocations.values.reduce(0, +)
        return MemorySnapshot(
            totalBytes: totalMemoryBytes,
            budgetBytes: maxBudgetBytes,
            allocatedBytes: allocated,
            availableBytes: allocated < maxBudgetBytes ? maxBudgetBytes - allocated : 0,
            containerAllocations: allocations
        )
    }

    public struct MemorySnapshot: Sendable {
        public let totalBytes: UInt64
        public let budgetBytes: UInt64
        public let allocatedBytes: UInt64
        public let availableBytes: UInt64
        public let containerAllocations: [String: UInt64]
    }
}

enum GPUMemoryError: Error, LocalizedError {
    case insufficientMemory(requested: UInt64, available: UInt64)

    var errorDescription: String? {
        switch self {
        case .insufficientMemory(let requested, let available):
            return "Insufficient GPU memory: requested \(requested / (1024*1024)) MB, available \(available / (1024*1024)) MB"
        }
    }
}
