// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HermesApp",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "HermesApp",
            targets: ["HermesApp"]
        ),
    ],
    dependencies: [
        // Phase 2: Markdown rendering and syntax highlighting
        .package(url: "https://github.com/gonzalezreal/MarkdownUI", from: "2.0.0"),
        .package(url: "https://github.com/JohnSundell/Splash", from: "0.16.0"),
    ],
    targets: [
        .target(
            name: "HermesApp",
            dependencies: [
                .product(name: "MarkdownUI", package: "MarkdownUI"),
                .product(name: "Splash", package: "Splash"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "HermesAppTests",
            dependencies: ["HermesApp"]
        ),
    ]
)
