// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DictatorApp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "DictatorCore", targets: ["DictatorCore"]),
        .executable(name: "DictatorApp", targets: ["DictatorAppMac"]),
        .executable(name: "DictatorLinux", targets: ["DictatorLinux"]),
        .executable(name: "dictator-linux", targets: ["DictatorLinux"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.67.0")
    ],
    targets: [
        .systemLibrary(
            name: "CWhisper",
            pkgConfig: "whisper"
        ),
        .target(
            name: "DictatorCore",
            dependencies: ["CWhisper"],
            path: "Sources/DictatorCore",
            linkerSettings: [
                .linkedLibrary("whisper"),
                .linkedLibrary("ggml", .when(platforms: [.linux, .macOS])),
                .linkedLibrary("ggml-base", .when(platforms: [.linux, .macOS])),
                .unsafeFlags([
                    "-L/opt/homebrew/Cellar/whisper-cpp/1.8.3/libexec/lib",
                    "-L/opt/homebrew/lib",
                    "-L/usr/local/lib"
                ], .when(platforms: [.macOS]))
            ]
        ),
        .target(
            name: "DictatorAppShared",
            dependencies: [
                "DictatorCore",
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio")
            ],
            path: "Sources/DictatorAppShared"
        ),
        .executableTarget(
            name: "DictatorAppMac",
            dependencies: [
                "DictatorCore",
                "DictatorAppShared",
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio")
            ],
            path: "Sources/DictatorApp",
            swiftSettings: [
                .define("DICTATOR_MAC")
            ]
        ),
        .executableTarget(
            name: "DictatorLinux",
            dependencies: [
                "DictatorCore",
                "DictatorAppShared",
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio")
            ],
            path: "Sources/DictatorLinux",
            swiftSettings: [
                .define("DICTATOR_LINUX")
            ]
        ),
        .testTarget(
            name: "DictatorAppTests",
            dependencies: ["DictatorAppMac"],
            path: "Tests/DictatorAppTests"
        ),
        .testTarget(
            name: "DictatorCoreTests",
            dependencies: ["DictatorCore"],
            path: "Tests/DictatorCoreTests"
        ),
        .testTarget(
            name: "DictatorLinuxTests",
            dependencies: ["DictatorLinux", "DictatorAppShared", "DictatorCore"],
            path: "Tests/DictatorLinuxTests"
        )
    ]
)
