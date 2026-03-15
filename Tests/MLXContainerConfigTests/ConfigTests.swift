import XCTest
import Foundation
@testable import MLXContainerConfig
@testable import MLXDeviceDiscovery

// MARK: - ToolkitConfiguration Tests

final class ToolkitConfigurationTests: XCTestCase {

    // MARK: - Default values

    func testDefaultVsockPort() {
        let config = ToolkitConfiguration()
        XCTAssertEqual(config.vsockPort, 2048)
        XCTAssertEqual(ToolkitConfiguration.defaultVsockPort, 2048)
    }

    func testDefaultModelsDirectory() {
        let config = ToolkitConfiguration()
        XCTAssertEqual(config.modelsDirectory, "~/.mlx-container/models")
        XCTAssertEqual(ToolkitConfiguration.defaultModelsDirectory, "~/.mlx-container/models")
    }

    func testDefaultMaxGPUMemoryBytes() {
        let config = ToolkitConfiguration()
        XCTAssertEqual(config.maxGPUMemoryBytes, 0)
    }

    func testDefaultMaxLoadedModels() {
        let config = ToolkitConfiguration()
        XCTAssertEqual(config.maxLoadedModels, 3)
    }

    func testDefaultLogLevel() {
        let config = ToolkitConfiguration()
        XCTAssertEqual(config.logLevel, "info")
    }

    func testDefaultEnableStreaming() {
        let config = ToolkitConfiguration()
        XCTAssertEqual(config.enableStreaming, true)
    }

    func testDefaultMaxTokens() {
        let config = ToolkitConfiguration()
        XCTAssertEqual(config.defaultMaxTokens, 512)
    }

    func testDefaultTemperature() {
        let config = ToolkitConfiguration()
        XCTAssertLessThan(abs(config.defaultTemperature - 0.7), 0.001)
    }

    // MARK: - Custom initialisation

    func testCustomInit() {
        let config = ToolkitConfiguration(
            vsockPort: 9090,
            modelsDirectory: "/tmp/models",
            maxGPUMemoryBytes: 8_000_000_000,
            maxLoadedModels: 5,
            logLevel: "debug",
            enableStreaming: false,
            defaultMaxTokens: 1024,
            defaultTemperature: 0.3
        )
        XCTAssertEqual(config.vsockPort, 9090)
        XCTAssertEqual(config.modelsDirectory, "/tmp/models")
        XCTAssertEqual(config.maxGPUMemoryBytes, 8_000_000_000)
        XCTAssertEqual(config.maxLoadedModels, 5)
        XCTAssertEqual(config.logLevel, "debug")
        XCTAssertEqual(config.enableStreaming, false)
        XCTAssertEqual(config.defaultMaxTokens, 1024)
        XCTAssertLessThan(abs(config.defaultTemperature - 0.3), 0.001)
    }

    // MARK: - resolvedModelsDirectory tilde expansion

    func testResolvedModelsDirectoryExpandsTilde() {
        let config = ToolkitConfiguration()
        let resolved = config.resolvedModelsDirectory
        let home = NSString(string: "~").expandingTildeInPath
        XCTAssertTrue(resolved.path.hasPrefix(home), "resolvedModelsDirectory should start with the home directory")
        XCTAssertFalse(resolved.path.contains("~"), "resolvedModelsDirectory must not contain a literal tilde")
    }

    func testResolvedModelsDirectoryAbsolutePath() {
        var config = ToolkitConfiguration()
        config.modelsDirectory = "/var/lib/mlx/models"
        let resolved = config.resolvedModelsDirectory
        XCTAssertEqual(resolved.path, "/var/lib/mlx/models")
    }

    func testResolvedModelsDirectoryPathSuffix() {
        let config = ToolkitConfiguration()
        let resolved = config.resolvedModelsDirectory
        XCTAssertTrue(resolved.path.hasSuffix(".mlx-container/models"))
    }

    // MARK: - Save / Load roundtrip

    func testSaveLoadRoundtrip() throws {
        let tmpDir = FileManager.default.temporaryDirectory
        let configURL = tmpDir.appendingPathComponent("test-config-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: configURL) }

        let original = ToolkitConfiguration(
            vsockPort: 3000,
            modelsDirectory: "/custom/models",
            maxGPUMemoryBytes: 4_000_000_000,
            maxLoadedModels: 2,
            logLevel: "warning",
            enableStreaming: false,
            defaultMaxTokens: 256,
            defaultTemperature: 0.5
        )

        try original.save(to: configURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: configURL.path), "Config file should exist after save")

        let loaded = try ToolkitConfiguration.load(from: configURL)

        XCTAssertEqual(loaded.vsockPort, original.vsockPort)
        XCTAssertEqual(loaded.modelsDirectory, original.modelsDirectory)
        XCTAssertEqual(loaded.maxGPUMemoryBytes, original.maxGPUMemoryBytes)
        XCTAssertEqual(loaded.maxLoadedModels, original.maxLoadedModels)
        XCTAssertEqual(loaded.logLevel, original.logLevel)
        XCTAssertEqual(loaded.enableStreaming, original.enableStreaming)
        XCTAssertEqual(loaded.defaultMaxTokens, original.defaultMaxTokens)
        XCTAssertLessThan(abs(loaded.defaultTemperature - original.defaultTemperature), 0.001)
    }

    func testLoadNonExistentReturnsDefaults() throws {
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonexistent-\(UUID().uuidString).json")
        let config = try ToolkitConfiguration.load(from: tmpURL)
        XCTAssertEqual(config.vsockPort, ToolkitConfiguration.defaultVsockPort)
        XCTAssertEqual(config.modelsDirectory, ToolkitConfiguration.defaultModelsDirectory)
        XCTAssertEqual(config.maxLoadedModels, 3)
    }

    func testSavesValidJSON() throws {
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("valid-json-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let config = ToolkitConfiguration()
        try config.save(to: tmpURL)

        let data = try Data(contentsOf: tmpURL)
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        XCTAssertTrue(json is [String: Any], "Saved config must be a JSON object")
    }

    func testSaveCreatesIntermediateDirectories() throws {
        let tmpDir = FileManager.default.temporaryDirectory
        let nestedURL = tmpDir
            .appendingPathComponent("nested-\(UUID().uuidString)")
            .appendingPathComponent("deep")
            .appendingPathComponent("config.json")
        defer {
            let parent = nestedURL.deletingLastPathComponent().deletingLastPathComponent()
            try? FileManager.default.removeItem(at: parent)
        }

        let config = ToolkitConfiguration()
        try config.save(to: nestedURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: nestedURL.path))
    }
}

// MARK: - ContainerGPUConfig Tests

final class ContainerGPUConfigTests: XCTestCase {

    // MARK: - Default values

    func testDefaultEnabled() {
        let config = ContainerGPUConfig()
        XCTAssertEqual(config.enabled, true)
    }

    func testDefaultMemoryBudget() {
        let config = ContainerGPUConfig()
        XCTAssertEqual(config.memoryBudgetBytes, 0)
    }

    func testDefaultPreloadModel() {
        let config = ContainerGPUConfig()
        XCTAssertNil(config.preloadModel)
    }

    func testDefaultMaxTokensPerRequest() {
        let config = ContainerGPUConfig()
        XCTAssertEqual(config.maxTokensPerRequest, 2048)
    }

    func testDefaultAllowModelManagement() {
        let config = ContainerGPUConfig()
        XCTAssertEqual(config.allowModelManagement, true)
    }

    func testDefaultContainerID() {
        let config = ContainerGPUConfig()
        XCTAssertNil(config.containerID)
    }

    // MARK: - .disabled static

    func testDisabledHasEnabledFalse() {
        let disabled = ContainerGPUConfig.disabled
        XCTAssertEqual(disabled.enabled, false)
    }

    func testDisabledHasZeroMemoryBudget() {
        let disabled = ContainerGPUConfig.disabled
        XCTAssertEqual(disabled.memoryBudgetBytes, 0)
    }

    func testDisabledHasNilPreloadModel() {
        let disabled = ContainerGPUConfig.disabled
        XCTAssertNil(disabled.preloadModel)
    }

    // MARK: - Custom values

    func testCustomContainerID() {
        let config = ContainerGPUConfig(containerID: "container-abc-123")
        XCTAssertEqual(config.containerID, "container-abc-123")
    }

    func testStoresPreloadModel() {
        let config = ContainerGPUConfig(preloadModel: "mlx-community/Llama-3.2-1B-4bit")
        XCTAssertEqual(config.preloadModel, "mlx-community/Llama-3.2-1B-4bit")
    }

    // MARK: - Codable roundtrip

    func testCodableRoundtrip() throws {
        let original = ContainerGPUConfig(
            enabled: true,
            memoryBudgetBytes: 2_000_000_000,
            preloadModel: "mlx-community/Qwen2.5-1.5B-4bit",
            maxTokensPerRequest: 4096,
            allowModelManagement: false,
            containerID: "ctr-0042"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ContainerGPUConfig.self, from: data)

        XCTAssertEqual(decoded.enabled, original.enabled)
        XCTAssertEqual(decoded.memoryBudgetBytes, original.memoryBudgetBytes)
        XCTAssertEqual(decoded.preloadModel, original.preloadModel)
        XCTAssertEqual(decoded.maxTokensPerRequest, original.maxTokensPerRequest)
        XCTAssertEqual(decoded.allowModelManagement, original.allowModelManagement)
        XCTAssertEqual(decoded.containerID, original.containerID)
    }

    func testDisabledCodableRoundtrip() throws {
        let data = try JSONEncoder().encode(ContainerGPUConfig.disabled)
        let decoded = try JSONDecoder().decode(ContainerGPUConfig.self, from: data)
        XCTAssertEqual(decoded.enabled, false)
    }
}
