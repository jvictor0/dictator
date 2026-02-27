// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "RoleRunnerServer",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "RoleRunnerCore", targets: ["RoleRunnerCore"]),
        .executable(name: "RoleRunnerServer", targets: ["RoleRunnerServer"])
    ],
    targets: [
        .target(
            name: "RoleRunnerCore",
            path: "Sources/RoleRunnerCore"
        ),
        .executableTarget(
            name: "RoleRunnerServer",
            dependencies: ["RoleRunnerCore"],
            path: "Sources/RoleRunnerServer"
        ),
        .testTarget(
            name: "RoleRunnerCoreTests",
            dependencies: ["RoleRunnerCore"],
            path: "Tests/RoleRunnerCoreTests"
        )
    ]
)
