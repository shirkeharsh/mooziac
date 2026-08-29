// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Mooziac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "Mooziac",
            targets: ["Mooziac"]
        ),
        .executable(
            name: "BrainWatcher",
            targets: ["BrainWatcher"]
        ),
        .executable(
            name: "MooziacStudio",
            targets: ["MooziacStudio"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Mooziac",
            path: "Sources/Mooziac"
        ),
        .executableTarget(
            name: "BrainWatcher",
            path: "Sources/BrainWatcher"
        ),
        .executableTarget(
            name: "MooziacStudio",
            path: "Sources/MooziacStudio"
        )
    ]
)
