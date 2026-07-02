// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OpenMetrics",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "OpenMetrics", targets: ["OpenMetrics"])
    ],
    targets: [
        .executableTarget(
            name: "OpenMetrics",
            linkerSettings: [.linkedFramework("IOKit")]
        ),
        .testTarget(
            name: "OpenMetricsTests",
            dependencies: ["OpenMetrics"]
        )
    ]
)
