// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "swift-cutelog",
    products: [
        .library(
            name: "Cutelog",
            targets: ["Cutelog"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", .upToNextMajor(from: "1.4.4")),
        .package(url: "https://github.com/Kitura/BlueSocket.git", .upToNextMajor(from: "2.0.2")),
        .package(url: "https://github.com/malcommac/SwiftMsgPack.git", .upToNextMajor(from: "1.2.0")),
    ],
    targets: [
        .target(
            name: "Cutelog",
            dependencies: [
                "SwiftMsgPack",
                .product(name: "Socket", package: "BlueSocket"),
                .product(name: "Logging", package: "swift-log"),
            ]
        ),
        .executableTarget(
            name: "Demo",
            dependencies: [
                "Cutelog"
            ]
        )
    ]
)
