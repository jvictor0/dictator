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
        .systemLibrary(
            name: "CWhisper"
        ),
        .target(
            name: "DictatorCore",
            dependencies: ["CWhisper"],
            path: "Sources/DictatorCore",
            linkerSettings: [
                .linkedLibrary("whisper"),
                .linkedLibrary("ggml"),
                .linkedLibrary("ggml-base"),
                .unsafeFlags([
                    "-L/opt/homebrew/Cellar/whisper-cpp/1.8.3/libexec/lib",
                    "-L/opt/homebrew/lib",
                    "-L/usr/local/lib"
                ])
            ]
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
