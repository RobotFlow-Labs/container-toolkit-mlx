// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "container-toolkit-mlx",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "mlx-ctk", targets: ["mlx-ctk"]),
        .executable(name: "mlx-container-daemon", targets: ["MLXContainerDaemon"]),
        .library(name: "MLXDeviceDiscovery", targets: ["MLXDeviceDiscovery"]),
        .library(name: "MLXContainerConfig", targets: ["MLXContainerConfig"]),
        .library(name: "MLXContainerProtocol", targets: ["MLXContainerProtocol"]),
        .library(name: "MLXContainerRuntime", targets: ["MLXContainerRuntime"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.0"),
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.28.0"),
        .package(url: "https://github.com/grpc/grpc-swift-2.git", exact: "2.1.0"),
        .package(url: "https://github.com/grpc/grpc-swift-nio-transport.git", exact: "2.1.0"),
        .package(url: "https://github.com/grpc/grpc-swift-protobuf.git", exact: "2.1.0"),
        .package(url: "https://github.com/ml-explore/mlx-swift.git", from: "0.21.0"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", from: "0.1.0"),
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

        // MARK: - Protocol (gRPC stubs)
        .target(
            name: "MLXContainerProtocol",
            dependencies: [
                .product(name: "GRPCProtobuf", package: "grpc-swift-protobuf"),
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
                .product(name: "GRPCProtobuf", package: "grpc-swift-protobuf"),
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXRandom", package: "mlx-swift"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
            ]
        ),

        // MARK: - CLI Tool
        .executableTarget(
            name: "mlx-ctk",
            dependencies: [
                "MLXDeviceDiscovery",
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
    ]
)
