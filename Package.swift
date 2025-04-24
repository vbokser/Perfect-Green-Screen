// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "Perfect Green Screen",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "Perfect Green Screen",
            targets: ["Perfect Green Screen"])
    ],
    dependencies: [
        .package(url: "https://github.com/r-n-i/DGCharts.git", branch: "master")
    ],
    targets: [
        .target(
            name: "Perfect Green Screen",
            dependencies: [
                .product(name: "DGCharts", package: "Charts")
            ],
            path: "Perfect Green Screen")
    ]
) 