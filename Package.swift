// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SpeechToCode",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SpeechToCode",
            targets: ["SpeechToCode"]),
    ],
    dependencies: [
        // Dependencies for OpenAI Realtime API
        .package(url: "https://github.com/vapor/websocket-kit.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "SpeechToCode",
            dependencies: [
                .product(name: "WebSocketKit", package: "websocket-kit"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
            ]),
        .testTarget(
            name: "SpeechToCodeTests",
            dependencies: ["SpeechToCode"]),
    ]
)
