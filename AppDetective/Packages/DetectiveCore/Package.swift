// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DetectiveCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DetectiveCore", targets: ["DetectiveCore"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/hewigovens/LSAppCategory.git",
            revision: "fe8edb78aaa41206e1a98b9bfbd0b0f26ed625c9"
        ),
    ],
    targets: [
        .target(
            name: "DetectiveCore",
            dependencies: ["LSAppCategory"]
        ),
    ]
)
