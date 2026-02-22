// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DictatorApp",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "DictatorCore", targets: ["DictatorCore"]),
        .executable(name: "DictatorApp", targets: ["DictatorApp"])
    ],
    targets: [
        .target(
            name: "DictatorCore",
            path: "Sources/DictatorCore"
        ),
        .executableTarget(
            name: "DictatorApp",
            dependencies: ["DictatorCore"],
            path: "Sources/DictatorApp"
        ),
        .testTarget(
            name: "DictatorAppTests",
            dependencies: ["DictatorApp"],
            path: "Tests/DictatorAppTests"
        ),
        .testTarget(
            name: "DictatorCoreTests",
            dependencies: ["DictatorCore"],
            path: "Tests/DictatorCoreTests"
        )
    ]
)
