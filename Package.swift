// swift-tools-version: 6.0
import PackageDescription

// This package tests the exact Foundation-only source compiled by the iOS app.
// It deliberately has no Firebase, UIKit or external package dependencies.
let package = Package(
    name: "LeagueDexARAMCore",
    platforms: [.macOS(.v13)],
    products: [.library(name: "ARAMCore", targets: ["ARAMCore"])],
    targets: [
        .target(name: "ARAMCore", path: "LeagueDex/ARAMCore"),
        .testTarget(name: "ARAMCoreTests", dependencies: ["ARAMCore"], path: "Tests/ARAMCoreTests")
    ]
)
