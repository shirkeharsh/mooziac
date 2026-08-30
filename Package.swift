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
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Mooziac",
            path: "Sources/Mooziac"
        )
    ]
)
