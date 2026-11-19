// swift-tools-version: 6.0
// HandspanCore: everything in the app that doesn't need UIKit, SwiftUI or AVFoundation.
// Pitch detection, note tracking, scoring, lesson content, the data layer and the
// attempt queue. Builds and tests on macOS (and Linux) with `swift test`.

import PackageDescription

let package = Package(
    name: "HandspanCore",
    platforms: [.iOS("26.0"), .macOS(.v14)],
    products: [
        .library(name: "HandspanCore", targets: ["HandspanCore"]),
    ],
    targets: [
        .target(name: "HandspanCore", resources: [.process("Resources")]),
        .testTarget(name: "HandspanCoreTests", dependencies: ["HandspanCore"]),
    ]
)
