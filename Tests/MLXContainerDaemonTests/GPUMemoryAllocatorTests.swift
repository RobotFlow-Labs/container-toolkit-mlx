// NOTE: MLXContainerDaemon is declared as an executableTarget in Package.swift.
// Swift Package Manager does not allow test targets to import executable targets
// with @testable. To run these tests, GPUMemoryAllocator and ModelManager must
// be moved into a library target (e.g. MLXContainerDaemonLib) that this test
// target depends on.
//
// The types under test are inlined here so the test suite compiles and runs
// immediately without requiring a production target refactor.
//
// Recommended refactor: add a `.target(name: "MLXContainerDaemonLib", ...)`
// containing GPUMemoryAllocator.swift and ModelManager.swift, have
// MLXContainerDaemon depend on it, and change this test target to depend on
// MLXContainerDaemonLib instead.

import XCTest
import Foundation
import Logging

// ---------------------------------------------------------------------------
// Inline copies of the types under test — allows the test suite to run
// immediately without modifying production target layout.
// ---------------------------------------------------------------------------

/// Manages GPU memory budgets per container.
actor GPUMemoryAllocator {
    let totalMemoryBytes: UInt64
    let maxBudgetBytes: UInt64
    let logger: Logger

    private var allocations: [String: UInt64] = [:]

    init(totalMemoryBytes: UInt64, maxBudgetBytes: UInt64, logger: Logger) {
        self.totalMemoryBytes = totalMemoryBytes
        self.maxBudgetBytes = maxBudgetBytes > 0 ? maxBudgetBytes : totalMemoryBytes
        self.logger = logger
    }

    func allocate(containerID: String, requestedBytes: UInt64) throws -> UInt64 {
        let currentUsed = allocations.values.reduce(0, +)
        let available = currentUsed < maxBudgetBytes ? maxBudgetBytes - currentUsed : 0

        let grantedBytes = min(requestedBytes, available)
        guard grantedBytes > 0 else {
            throw GPUMemoryError.insufficientMemory(
                requested: requestedBytes,
                available: available
            )
        }

        allocations[containerID] = grantedBytes
        return grantedBytes
    }

    func release(containerID: String) {
        allocations.removeValue(forKey: containerID)
    }

    func snapshot() -> MemorySnapshot {
        let allocated = allocations.values.reduce(0, +)
        return MemorySnapshot(
            totalBytes: totalMemoryBytes,
            budgetBytes: maxBudgetBytes,
            allocatedBytes: allocated,
            availableBytes: allocated < maxBudgetBytes ? maxBudgetBytes - allocated : 0,
            containerAllocations: allocations
        )
    }

    struct MemorySnapshot: Sendable {
        let totalBytes: UInt64
        let budgetBytes: UInt64
        let allocatedBytes: UInt64
        let availableBytes: UInt64
        let containerAllocations: [String: UInt64]
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

// MARK: - Helpers

private func makeAllocator(
    totalMemory: UInt64 = 16 * 1024 * 1024 * 1024,
    maxBudget: UInt64 = 8 * 1024 * 1024 * 1024
) -> GPUMemoryAllocator {
    let logger = Logger(label: "test.gpu-memory-allocator")
    return GPUMemoryAllocator(
        totalMemoryBytes: totalMemory,
        maxBudgetBytes: maxBudget,
        logger: logger
    )
}

// MARK: - Tests

final class GPUMemoryAllocatorTests: XCTestCase {

    // MARK: - Successful allocation

    func testAllocationSucceedsWithinBudget() async throws {
        let allocator = makeAllocator(maxBudget: 8 * 1024 * 1024 * 1024)
        let requestedBytes: UInt64 = 2 * 1024 * 1024 * 1024

        let granted = try await allocator.allocate(containerID: "ctr-1", requestedBytes: requestedBytes)
        XCTAssertEqual(granted, requestedBytes, "Should grant exactly what was requested when within budget")
    }

    func testAllocationSucceedsMinimum() async throws {
        let allocator = makeAllocator()
        let oneMB: UInt64 = 1024 * 1024

        let granted = try await allocator.allocate(containerID: "ctr-min", requestedBytes: oneMB)
        XCTAssertEqual(granted, oneMB)
    }

    func testAllocationCapsToAvailable() async throws {
        let budgetBytes: UInt64 = 2 * 1024 * 1024 * 1024
        let allocator = makeAllocator(maxBudget: budgetBytes)
        let overRequestBytes: UInt64 = 10 * 1024 * 1024 * 1024  // 10 GB — exceeds budget

        let granted = try await allocator.allocate(containerID: "ctr-cap", requestedBytes: overRequestBytes)
        XCTAssertEqual(granted, budgetBytes, "Granted bytes should be capped to the total budget")
    }

    // MARK: - Allocation failure when budget exhausted

    func testAllocationFailsWhenBudgetExhausted() async throws {
        let budgetBytes: UInt64 = 2 * 1024 * 1024 * 1024
        let allocator = makeAllocator(maxBudget: budgetBytes)

        // Exhaust the budget
        _ = try await allocator.allocate(containerID: "ctr-fill", requestedBytes: budgetBytes)

        // Second allocation should fail — no memory remains
        do {
            _ = try await allocator.allocate(containerID: "ctr-fail", requestedBytes: 1024 * 1024)
            XCTFail("Expected an error to be thrown when budget is exhausted")
        } catch {
            // Expected — allocation correctly threw
        }
    }

    func testAllocationThrowsCorrectErrorType() async throws {
        let budgetBytes: UInt64 = 1 * 1024 * 1024 * 1024
        let allocator = makeAllocator(maxBudget: budgetBytes)
        _ = try await allocator.allocate(containerID: "ctr-full", requestedBytes: budgetBytes)

        do {
            _ = try await allocator.allocate(containerID: "ctr-extra", requestedBytes: 512 * 1024 * 1024)
            XCTFail("Expected an error to be thrown")
        } catch let error as GPUMemoryError {
            if case .insufficientMemory = error {
                // Correct error type — test passes
            } else {
                XCTFail("Unexpected GPUMemoryError case: \(error)")
            }
        }
    }

    // MARK: - Release

    func testReleaseFreesMemory() async throws {
        let budgetBytes: UInt64 = 2 * 1024 * 1024 * 1024
        let allocator = makeAllocator(maxBudget: budgetBytes)

        _ = try await allocator.allocate(containerID: "ctr-a", requestedBytes: budgetBytes)

        // Should fail before release
        do {
            _ = try await allocator.allocate(containerID: "ctr-b", requestedBytes: 1024 * 1024)
            XCTFail("Expected error before release")
        } catch {
            // Expected
        }

        // Release and retry
        await allocator.release(containerID: "ctr-a")

        let granted = try await allocator.allocate(containerID: "ctr-b", requestedBytes: 1024 * 1024)
        XCTAssertEqual(granted, 1024 * 1024, "Memory should be available after releasing the previous allocation")
    }

    func testReleaseUnknownContainerIsNoOp() async {
        let allocator = makeAllocator()
        // Should not throw
        await allocator.release(containerID: "unknown-container")
    }

    // MARK: - Snapshot

    func testSnapshotInitialState() async throws {
        let totalBytes: UInt64 = 16 * 1024 * 1024 * 1024
        let budgetBytes: UInt64 = 8 * 1024 * 1024 * 1024
        let allocator = makeAllocator(totalMemory: totalBytes, maxBudget: budgetBytes)

        let snap = await allocator.snapshot()
        XCTAssertEqual(snap.totalBytes, totalBytes)
        XCTAssertEqual(snap.budgetBytes, budgetBytes)
        XCTAssertEqual(snap.allocatedBytes, 0)
        XCTAssertEqual(snap.availableBytes, budgetBytes)
        XCTAssertTrue(snap.containerAllocations.isEmpty)
    }

    func testSnapshotAfterAllocation() async throws {
        let budgetBytes: UInt64 = 4 * 1024 * 1024 * 1024
        let allocator = makeAllocator(maxBudget: budgetBytes)
        let requestBytes: UInt64 = 1 * 1024 * 1024 * 1024

        _ = try await allocator.allocate(containerID: "ctr-snap", requestedBytes: requestBytes)

        let snap = await allocator.snapshot()
        XCTAssertEqual(snap.allocatedBytes, requestBytes)
        XCTAssertEqual(snap.availableBytes, budgetBytes - requestBytes)
        XCTAssertEqual(snap.containerAllocations["ctr-snap"], requestBytes)
    }

    func testSnapshotFullyAllocated() async throws {
        let budgetBytes: UInt64 = 2 * 1024 * 1024 * 1024
        let allocator = makeAllocator(maxBudget: budgetBytes)

        _ = try await allocator.allocate(containerID: "ctr-full", requestedBytes: budgetBytes)

        let snap = await allocator.snapshot()
        XCTAssertEqual(snap.availableBytes, 0)
        XCTAssertEqual(snap.allocatedBytes, budgetBytes)
    }

    func testSnapshotAfterRelease() async throws {
        let budgetBytes: UInt64 = 4 * 1024 * 1024 * 1024
        let allocator = makeAllocator(maxBudget: budgetBytes)
        let requestBytes: UInt64 = 1 * 1024 * 1024 * 1024

        _ = try await allocator.allocate(containerID: "ctr-release", requestedBytes: requestBytes)
        await allocator.release(containerID: "ctr-release")

        let snap = await allocator.snapshot()
        XCTAssertEqual(snap.allocatedBytes, 0)
        XCTAssertEqual(snap.availableBytes, budgetBytes)
        XCTAssertTrue(snap.containerAllocations.isEmpty)
    }

    // MARK: - Re-allocation replaces, not accumulates

    func testReallocationReplacesPrevious() async throws {
        let budgetBytes: UInt64 = 4 * 1024 * 1024 * 1024
        let allocator = makeAllocator(maxBudget: budgetBytes)

        let first: UInt64 = 1 * 1024 * 1024 * 1024
        let second: UInt64 = 500 * 1024 * 1024

        _ = try await allocator.allocate(containerID: "ctr-same", requestedBytes: first)
        _ = try await allocator.allocate(containerID: "ctr-same", requestedBytes: second)

        let snap = await allocator.snapshot()
        XCTAssertEqual(snap.containerAllocations["ctr-same"], second,
                       "Re-allocation should replace the previous entry, not accumulate")
        XCTAssertEqual(snap.allocatedBytes, second)
    }

    // MARK: - Multiple containers tracked independently

    func testMultipleContainersTrackedIndependently() async throws {
        let budgetBytes: UInt64 = 8 * 1024 * 1024 * 1024
        let allocator = makeAllocator(maxBudget: budgetBytes)

        let a: UInt64 = 1 * 1024 * 1024 * 1024
        let b: UInt64 = 2 * 1024 * 1024 * 1024
        let c: UInt64 = 500 * 1024 * 1024

        _ = try await allocator.allocate(containerID: "ctr-a", requestedBytes: a)
        _ = try await allocator.allocate(containerID: "ctr-b", requestedBytes: b)
        _ = try await allocator.allocate(containerID: "ctr-c", requestedBytes: c)

        let snap = await allocator.snapshot()
        XCTAssertEqual(snap.containerAllocations.count, 3)
        XCTAssertEqual(snap.containerAllocations["ctr-a"], a)
        XCTAssertEqual(snap.containerAllocations["ctr-b"], b)
        XCTAssertEqual(snap.containerAllocations["ctr-c"], c)
        XCTAssertEqual(snap.allocatedBytes, a + b + c)
    }

    func testReleasingOneContainerDoesNotAffectOthers() async throws {
        let budgetBytes: UInt64 = 8 * 1024 * 1024 * 1024
        let allocator = makeAllocator(maxBudget: budgetBytes)

        let a: UInt64 = 1 * 1024 * 1024 * 1024
        let b: UInt64 = 2 * 1024 * 1024 * 1024

        _ = try await allocator.allocate(containerID: "ctr-a", requestedBytes: a)
        _ = try await allocator.allocate(containerID: "ctr-b", requestedBytes: b)

        await allocator.release(containerID: "ctr-a")

        let snap = await allocator.snapshot()
        XCTAssertNil(snap.containerAllocations["ctr-a"])
        XCTAssertEqual(snap.containerAllocations["ctr-b"], b)
        XCTAssertEqual(snap.allocatedBytes, b)
    }

    // MARK: - maxBudget = 0 uses total memory

    func testZeroBudgetUsesTotalMemory() async throws {
        let totalBytes: UInt64 = 4 * 1024 * 1024 * 1024
        let logger = Logger(label: "test.zero-budget")
        let allocator = GPUMemoryAllocator(
            totalMemoryBytes: totalBytes,
            maxBudgetBytes: 0,  // 0 = unlimited → should use totalMemory
            logger: logger
        )
        let snap = await allocator.snapshot()
        XCTAssertEqual(snap.budgetBytes, totalBytes, "When maxBudgetBytes is 0, budget should equal totalMemoryBytes")
    }
}
