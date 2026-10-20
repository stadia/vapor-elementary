// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "vapor-elementary",
    platforms: [.macOS("26.2"), .iOS("26.2"), .tvOS("26.2"), .watchOS("26.2")],
    products: [.library(name: "VaporElementary", targets: ["VaporElementary"])],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", exact: "5.0.0-beta.4"),
        .package(url: "https://github.com/elementary-swift/elementary.git", from: "0.8.2"),
        .package(url: "https://github.com/apple/swift-async-algorithms.git", from: "1.0.0"),
    ],
    targets: [
        .target(name: "VaporElementary", dependencies: [
            .product(name: "Vapor", package: "vapor"),
            .product(name: "Elementary", package: "elementary"),
            .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
        ], swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]),
        .testTarget(name: "VaporElementaryTests", dependencies: [
            "VaporElementary",
            .product(name: "Elementary", package: "elementary"),
            .product(name: "VaporTesting", package: "vapor"),
        ], swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]),
    ]
)
