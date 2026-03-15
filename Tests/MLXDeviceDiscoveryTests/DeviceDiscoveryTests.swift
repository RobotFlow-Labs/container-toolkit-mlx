import XCTest
import Foundation
@testable import MLXDeviceDiscovery

final class DeviceDiscoveryTests: XCTestCase {

    // MARK: - discover()

    func testDiscoverReturnsDevices() {
        let devices = DeviceDiscovery.discover()
        // Metal is available on all supported macOS 15+ Apple Silicon machines
        XCTAssertFalse(devices.isEmpty, "Expected at least one Metal GPU device on Apple Silicon macOS")
    }

    func testDiscoverDeviceHasName() {
        let devices = DeviceDiscovery.discover()
        guard let first = devices.first else {
            // No devices discovered — skipping name check
            return
        }
        XCTAssertFalse(first.name.isEmpty, "GPU device name must not be empty")
    }

    func testDiscoverDeviceHasPositiveMemory() {
        let devices = DeviceDiscovery.discover()
        guard let first = devices.first else {
            // No devices discovered — skipping memory check
            return
        }
        XCTAssertGreaterThan(first.unifiedMemoryBytes, 0, "unifiedMemoryBytes must be > 0")
        XCTAssertGreaterThan(first.recommendedMaxWorkingSetSize, 0, "recommendedMaxWorkingSetSize must be > 0")
    }

    func testDiscoverDeviceHasGPUFamily() {
        let devices = DeviceDiscovery.discover()
        guard let first = devices.first else {
            // No devices discovered — skipping gpuFamily check
            return
        }
        XCTAssertFalse(first.gpuFamily.isEmpty, "gpuFamily must not be empty")
    }

    // MARK: - defaultDevice()

    func testDefaultDeviceMatchesDiscover() {
        let first = DeviceDiscovery.discover().first
        let defaultDev = DeviceDiscovery.defaultDevice()
        XCTAssertEqual(first?.name, defaultDev?.name)
    }

    // MARK: - systemMemoryBytes()

    func testSystemMemoryBytesPositive() {
        let mem = DeviceDiscovery.systemMemoryBytes()
        XCTAssertGreaterThan(mem, 0, "System memory must be positive")
    }

    func testSystemMemoryBytesAtLeast1GB() {
        let mem = DeviceDiscovery.systemMemoryBytes()
        let oneGB: UInt64 = 1024 * 1024 * 1024
        XCTAssertGreaterThanOrEqual(mem, oneGB, "System memory should be at least 1 GB on any supported machine")
    }

    // MARK: - chipName()

    func testChipNameNonNil() {
        let name = DeviceDiscovery.chipName()
        XCTAssertNotNil(name, "chipName() should return a non-nil string on Apple Silicon macOS")
    }

    func testChipNameNonEmpty() {
        guard let name = DeviceDiscovery.chipName() else {
            // chipName() returned nil — skipping non-empty check
            return
        }
        XCTAssertFalse(name.isEmpty, "chipName() must return a non-empty string")
    }

    // MARK: - AppleGPUDevice Codable roundtrip

    func testAppleGPUDeviceCodableRoundtrip() throws {
        let original = AppleGPUDevice(
            name: "Apple M3 Max",
            registryID: 0xDEADBEEF_CAFEBABE,
            recommendedMaxWorkingSetSize: 68_719_476_736,
            gpuFamily: "metal3",
            unifiedMemoryBytes: 137_438_953_472,
            maxThreadsPerThreadgroup: 1024,
            supportsMetal3: true,
            hasUnifiedMemory: true
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        XCTAssertFalse(data.isEmpty, "Encoded data must not be empty")

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AppleGPUDevice.self, from: data)

        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.registryID, original.registryID)
        XCTAssertEqual(decoded.recommendedMaxWorkingSetSize, original.recommendedMaxWorkingSetSize)
        XCTAssertEqual(decoded.gpuFamily, original.gpuFamily)
        XCTAssertEqual(decoded.unifiedMemoryBytes, original.unifiedMemoryBytes)
        XCTAssertEqual(decoded.maxThreadsPerThreadgroup, original.maxThreadsPerThreadgroup)
        XCTAssertEqual(decoded.supportsMetal3, original.supportsMetal3)
        XCTAssertEqual(decoded.hasUnifiedMemory, original.hasUnifiedMemory)
    }

    func testAppleGPUDeviceCodableMinimalValues() throws {
        let original = AppleGPUDevice(
            name: "",
            registryID: 0,
            recommendedMaxWorkingSetSize: 0,
            gpuFamily: "",
            unifiedMemoryBytes: 0,
            maxThreadsPerThreadgroup: 0,
            supportsMetal3: false,
            hasUnifiedMemory: false
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppleGPUDevice.self, from: data)

        XCTAssertEqual(decoded.name, "")
        XCTAssertEqual(decoded.registryID, 0)
        XCTAssertEqual(decoded.supportsMetal3, false)
        XCTAssertEqual(decoded.hasUnifiedMemory, false)
    }

    func testAppleGPUDeviceDescriptionContainsName() {
        let device = AppleGPUDevice(
            name: "Apple M2 Pro",
            registryID: 1,
            recommendedMaxWorkingSetSize: 1024 * 1024 * 1024,
            gpuFamily: "apple9",
            unifiedMemoryBytes: 16 * 1024 * 1024 * 1024,
            maxThreadsPerThreadgroup: 1024,
            supportsMetal3: false,
            hasUnifiedMemory: true
        )
        XCTAssertTrue(device.description.contains("Apple M2 Pro"))
    }

    func testDiscoveredDeviceCodableRoundtrip() throws {
        guard let device = DeviceDiscovery.defaultDevice() else {
            // No device available — skipping live Codable roundtrip
            return
        }
        let data = try JSONEncoder().encode(device)
        let decoded = try JSONDecoder().decode(AppleGPUDevice.self, from: data)
        XCTAssertEqual(decoded.name, device.name)
        XCTAssertEqual(decoded.registryID, device.registryID)
        XCTAssertEqual(decoded.gpuFamily, device.gpuFamily)
        XCTAssertEqual(decoded.unifiedMemoryBytes, device.unifiedMemoryBytes)
    }
}
