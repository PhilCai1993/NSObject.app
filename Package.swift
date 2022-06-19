// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "NSObject",
    platforms: [.macOS(.v12)],
    products: [
        .executable(
            name: "NSObject",
            targets: ["NSObject"]
        )
    ],
    dependencies: [
        .package(name: "Publish", url: "https://github.com/johnsundell/publish.git", from: "0.8.0"),
        .package(name: "CNAMEPublishPlugin", url: "https://github.com/SwiftyGuerrero/CNAMEPublishPlugin", branch: "master")
    ],
    targets: [
        .executableTarget(
            name: "NSObject",
            dependencies: ["Publish","CNAMEPublishPlugin"]
        )
    ]
)
