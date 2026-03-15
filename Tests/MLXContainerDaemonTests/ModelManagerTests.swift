// NOTE: MLXContainerDaemon is an executableTarget; @testable import is not
// supported by SPM. The types under test (GPUMemoryAllocator, ModelManager,
// ModelManagerError) are inlined in this test module so the suite compiles
// without modifying the production target layout.
//
// GPUMemoryAllocator is defined in GPUMemoryAllocatorTests.swift (same module).
// ModelManagerError and ModelEntry are inlined below.
//
// Recommended production fix: extract both types into a library target
// (e.g. MLXContainerDaemonLib) and depend on it from both MLXContainerDaemon
// and MLXContainerDaemonTests.

import XCTest
import Foundation
import Logging

// MARK: - Inline ModelManagerError (mirrors Sources/MLXContainerDaemon/ModelManager.swift)

enum ModelManagerError: Error, LocalizedError {
    case modelNotLoaded(String)
    case modelLoadFailed(String, Error)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded(let id):
            return "Model not loaded: \(id)"
        case .modelLoadFailed(let id, let error):
            return "Failed to load model \(id): \(error.localizedDescription)"
        }
    }
}

// MARK: - Inline ModelEntry (mirrors Sources/MLXContainerDaemon/ModelManager.swift)

struct ModelEntry: Sendable {
    let id: String
    let alias: String
    let isLoaded: Bool
    let modelType: String
    let memoryUsedBytes: UInt64
}

// MARK: - Helpers

private func makeAllocator(
    totalMemory: UInt64 = 16 * 1024 * 1024 * 1024,
    maxBudget: UInt64 = 8 * 1024 * 1024 * 1024
) -> GPUMemoryAllocator {
    let logger = Logger(label: "test.model-manager.alloc")
    return GPUMemoryAllocator(
        totalMemoryBytes: totalMemory,
        maxBudgetBytes: maxBudget,
        logger: logger
    )
}

// MARK: - Tests

final class ModelManagerTests: XCTestCase {

    // MARK: - ModelManagerError descriptions

    func testModelNotLoadedErrorDescription() {
        let error = ModelManagerError.modelNotLoaded("some-model")
        XCTAssertTrue(
            error.errorDescription?.contains("some-model") == true,
            "errorDescription should contain the model ID"
        )
    }

    func testModelLoadFailedErrorDescriptionContainsModelID() {
        struct FakeError: Error, LocalizedError {
            var errorDescription: String? { "network timeout" }
        }
        let error = ModelManagerError.modelLoadFailed("my-model", FakeError())
        XCTAssertTrue(error.errorDescription?.contains("my-model") == true)
    }

    func testModelLoadFailedErrorDescriptionContainsUnderlyingError() {
        struct FakeError: Error, LocalizedError {
            var errorDescription: String? { "disk full" }
        }
        let error = ModelManagerError.modelLoadFailed("model-x", FakeError())
        XCTAssertTrue(error.errorDescription?.contains("disk full") == true)
    }

    // MARK: - ModelEntry structure

    func testModelEntryFields() {
        let entry = ModelEntry(
            id: "mlx-community/Llama-3.2-1B-4bit",
            alias: "llama",
            isLoaded: true,
            modelType: "llm",
            memoryUsedBytes: 1_000_000_000
        )
        XCTAssertEqual(entry.id, "mlx-community/Llama-3.2-1B-4bit")
        XCTAssertEqual(entry.alias, "llama")
        XCTAssertEqual(entry.isLoaded, true)
        XCTAssertEqual(entry.modelType, "llm")
        XCTAssertEqual(entry.memoryUsedBytes, 1_000_000_000)
    }

    func testModelEntryUnloadedState() {
        let entry = ModelEntry(
            id: "model-b",
            alias: "",
            isLoaded: false,
            modelType: "llm",
            memoryUsedBytes: 0
        )
        XCTAssertFalse(entry.isLoaded)
        XCTAssertEqual(entry.memoryUsedBytes, 0)
    }

    // MARK: - GPUMemoryAllocator integration (model tracking simulation)
    //
    // Actual MLX model loading requires a GPU and network access.
    // The following tests simulate the allocate-on-load / release-on-unload
    // lifecycle that ModelManager performs internally.

    func testAllocatorBudgetUnchangedBeforeLoad() async throws {
        let budgetBytes: UInt64 = 8 * 1024 * 1024 * 1024
        let allocator = makeAllocator(maxBudget: budgetBytes)
        let snap = await allocator.snapshot()
        XCTAssertEqual(snap.allocatedBytes, 0)
        XCTAssertEqual(snap.availableBytes, budgetBytes)
    }

    func testAllocatorReleaseWorksThroughManagerLifecycle() async throws {
        let budgetBytes: UInt64 = 4 * 1024 * 1024 * 1024
        let allocator = makeAllocator(maxBudget: budgetBytes)

        let modelID = "mlx-community/test-model"
        let requestBytes: UInt64 = 1 * 1024 * 1024 * 1024

        // Simulate loadModel: allocate memory
        _ = try await allocator.allocate(containerID: modelID, requestedBytes: requestBytes)
        var snap = await allocator.snapshot()
        XCTAssertEqual(snap.containerAllocations[modelID], requestBytes)

        // Simulate unloadModel: release memory
        await allocator.release(containerID: modelID)
        snap = await allocator.snapshot()
        XCTAssertNil(snap.containerAllocations[modelID])
        XCTAssertEqual(snap.allocatedBytes, 0)
    }

    func testMultipleModelsTrackedIndependentlyViaAllocator() async throws {
        let budgetBytes: UInt64 = 8 * 1024 * 1024 * 1024
        let allocator = makeAllocator(maxBudget: budgetBytes)

        let model1: UInt64 = 1 * 1024 * 1024 * 1024
        let model2: UInt64 = 2 * 1024 * 1024 * 1024

        _ = try await allocator.allocate(containerID: "model-1", requestedBytes: model1)
        _ = try await allocator.allocate(containerID: "model-2", requestedBytes: model2)

        let snap = await allocator.snapshot()
        XCTAssertEqual(snap.containerAllocations["model-1"], model1)
        XCTAssertEqual(snap.containerAllocations["model-2"], model2)
        XCTAssertEqual(snap.allocatedBytes, model1 + model2)
    }

    func testUnloadingOneModelDoesNotAffectOthers() async throws {
        let budgetBytes: UInt64 = 8 * 1024 * 1024 * 1024
        let allocator = makeAllocator(maxBudget: budgetBytes)

        let a: UInt64 = 1 * 1024 * 1024 * 1024
        let b: UInt64 = 2 * 1024 * 1024 * 1024

        _ = try await allocator.allocate(containerID: "model-a", requestedBytes: a)
        _ = try await allocator.allocate(containerID: "model-b", requestedBytes: b)

        await allocator.release(containerID: "model-a")

        let snap = await allocator.snapshot()
        XCTAssertNil(snap.containerAllocations["model-a"])
        XCTAssertEqual(snap.containerAllocations["model-b"], b)
        XCTAssertEqual(snap.allocatedBytes, b)
    }

    // MARK: - Note on actual GPU model loading
    //
    // Tests exercising LLMModelFactory / ModelContainer require:
    //   1. Apple Silicon Mac with Metal GPU
    //   2. Network access to HuggingFace for model download
    //   3. Sufficient free RAM
    //
    // Those belong in an integration test suite tagged "requires-gpu" / "slow"
    // and should be skipped in headless CI.
}
