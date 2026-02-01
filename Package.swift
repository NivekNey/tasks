// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TasksApp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "TasksApp", targets: ["TasksApp"]),
        .library(name: "TasksCore", targets: ["TasksCore"])
    ],
    targets: [
        .target(
            name: "TasksCore",
            path: "Sources/TasksCore"
        ),
        .executableTarget(
            name: "TasksApp",
            dependencies: ["TasksCore"],
            path: "Sources/TasksApp"
        ),
        .testTarget(
            name: "TasksTests",
            dependencies: ["TasksCore"],
            path: "Tests/TasksTests"
        )
    ]
)
