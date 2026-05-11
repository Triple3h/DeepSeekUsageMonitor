// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "DeepSeekUsageMonitor",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "DeepSeekUsageMonitor", targets: ["DeepSeekUsageMonitor"])
    ],
    targets: [
        .target(
            name: "DeepSeekUsageMonitorCore",
            path: "Sources/DeepSeekUsageMonitorCore"
        ),
        .executableTarget(
            name: "DeepSeekUsageMonitor",
            dependencies: ["DeepSeekUsageMonitorCore"],
            path: "Sources/DeepSeekUsageMonitor"
        )
    ]
)
