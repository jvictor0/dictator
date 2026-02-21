// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DictatorApp",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "DictatorApp", targets: ["DictatorApp"])
    ],
    targets: [
        .executableTarget(
            name: "DictatorApp",
            path: "Sources/DictatorApp"
        ),
        .testTarget(
            name: "DictatorAppTests",
            dependencies: ["DictatorApp"],
            path: "Tests/DictatorAppTests"
        )
    ]
)
