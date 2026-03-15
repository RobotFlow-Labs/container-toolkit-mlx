import Foundation
import Logging

/// Sets up vsock relay between the container VM and the GPU daemon.
/// Follows the pattern from apple-containerization's Vminitd+SocketRelay.swift.
///
/// The relay bridges the vsock port from the container's VM to the daemon
/// listening on the host, allowing gRPC communication across the VM boundary.
public struct GPUVsockRelay: Sendable {
    /// Default vsock port for the GPU daemon
    public static let defaultPort: UInt32 = 2048

    /// vsock CID for the host
    public static let hostCID: UInt32 = 2

    let port: UInt32
    let logger: Logger

    public init(port: UInt32 = Self.defaultPort, logger: Logger) {
        self.port = port
        self.logger = logger
    }

    /// Configuration needed to set up the vsock relay for a container.
    /// This would be passed to the VM configuration when creating the container.
    public struct RelayConfiguration: Sendable, Codable {
        /// The vsock port to forward
        public let port: UInt32
        /// The host CID
        public let hostCID: UInt32
        /// Direction: guest connects to host daemon
        public let direction: Direction

        public enum Direction: String, Sendable, Codable {
            case guestToHost = "guest_to_host"
        }

        public init(port: UInt32 = GPUVsockRelay.defaultPort) {
            self.port = port
            self.hostCID = GPUVsockRelay.hostCID
            self.direction = .guestToHost
        }
    }

    /// Generate the relay configuration for a GPU-enabled container.
    public func relayConfig() -> RelayConfiguration {
        RelayConfiguration(port: port)
    }

    /// Validate that vsock is available on this system.
    public static func validateVsockSupport() -> Bool {
        // On macOS with Apple's container framework, vsock is always available
        // through the Virtualization framework
        #if os(macOS)
        return true
        #else
        return false
        #endif
    }
}
