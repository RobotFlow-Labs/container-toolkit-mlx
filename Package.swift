// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "container-toolkit-mlx",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "mlx-ctk", targets: ["mlx-ctk"]),
        .executable(name: "mlx-container-daemon", targets: ["MLXContainerDaemon"]),
        .executable(name: "mlx-cdi-hook", targets: ["mlx-cdi-hook"]),
        .library(name: "MLXDeviceDiscovery", targets: ["MLXDeviceDiscovery"]),
        .library(name: "MLXContainerConfig", targets: ["MLXContainerConfig"]),
        .library(name: "MLXContainerProtocol", targets: ["MLXContainerProtocol"]),
        .library(name: "MLXContainerRuntime", targets: ["MLXContainerRuntime"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.7.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.9.0"),
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.28.0"),
        .package(url: "https://github.com/grpc/grpc-swift-2.git", from: "2.3.0"),
        .package(url: "https://github.com/grpc/grpc-swift-nio-transport.git", from: "2.4.0"),
        .package(url: "https://github.com/grpc/grpc-swift-protobuf.git", from: "2.2.0"),
        .package(url: "https://github.com/ml-explore/mlx-swift.git", .upToNextMinor(from: "0.30.6")),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", .upToNextMinor(from: "2.30.6")),
    ],
    targets: [
        // MARK: - Device Discovery
        .target(
            name: "MLXDeviceDiscovery",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
            ]
        ),

        // MARK: - Configuration
        .target(
            name: "MLXContainerConfig",
            dependencies: [
                "MLXDeviceDiscovery",
                .product(name: "Logging", package: "swift-log"),
            ]
        ),

        // MARK: - Protocol (gRPC service + JSON-serialized messages)
        .target(
            name: "MLXContainerProtocol",
            dependencies: [
                .product(name: "GRPCCore", package: "grpc-swift-2"),
            ]
        ),

        // MARK: - Host Daemon
        .executableTarget(
            name: "MLXContainerDaemon",
            dependencies: [
                "MLXDeviceDiscovery",
                "MLXContainerConfig",
                "MLXContainerProtocol",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "GRPCCore", package: "grpc-swift-2"),
                .product(name: "GRPCNIOTransportHTTP2", package: "grpc-swift-nio-transport"),
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXRandom", package: "mlx-swift"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXEmbedders", package: "mlx-swift-lm"),
            ]
        ),

        // MARK: - CLI Tool
        .executableTarget(
            name: "mlx-ctk",
            dependencies: [
                "MLXDeviceDiscovery",
                "MLXContainerConfig",
                "MLXContainerProtocol",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "GRPCCore", package: "grpc-swift-2"),
                .product(name: "GRPCNIOTransportHTTP2", package: "grpc-swift-nio-transport"),
            ]
        ),

        // MARK: - CDI Hook
        .executableTarget(
            name: "mlx-cdi-hook",
            dependencies: [
                "MLXContainerConfig",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
            ]
        ),

        // MARK: - Container Runtime Integration
        .target(
            name: "MLXContainerRuntime",
            dependencies: [
                "MLXContainerConfig",
                .product(name: "Logging", package: "swift-log"),
            ]
        ),

        // MARK: - Tests
        .testTarget(
            name: "MLXDeviceDiscoveryTests",
            dependencies: [
                "MLXDeviceDiscovery",
            ]
        ),
        .testTarget(
            name: "MLXContainerConfigTests",
            dependencies: [
                "MLXContainerConfig",
                "MLXDeviceDiscovery",
            ]
        ),
        .testTarget(
            name: "MLXContainerProtocolTests",
            dependencies: [
                "MLXContainerProtocol",
            ]
        ),
        // MLXContainerDaemon is an executableTarget — not importable by test targets.
        // GPUMemoryAllocator and ModelManager are inlined in the test files.
        // Only swift-log is needed as a direct dependency.
        .testTarget(
            name: "MLXContainerDaemonTests",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
            ]
        ),
    ]
)
