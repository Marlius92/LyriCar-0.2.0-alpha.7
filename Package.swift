// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LyriCar",
    platforms: [
        .macOS(.v15),
        .iOS(.v18)
    ],
    products: [
        .library(name: "LyriCarCore", targets: ["LyriCarCore"]),
        .executable(name: "lyricar-core-demo", targets: ["LyriCarCoreDemo"])
    ],
    targets: [
        .target(
            name: "LyriCarCore",
            path: "Sources/LyriCarCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "LyriCarCoreDemo",
            dependencies: ["LyriCarCore"],
            path: "Sources/LyriCarCoreDemo",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "LyriCarCoreTests",
            dependencies: ["LyriCarCore"],
            path: "Tests/LyriCarCoreTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ],
    swiftLanguageModes: [.v5]
)
