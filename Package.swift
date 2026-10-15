// swift-tools-version: 6.0
import PackageDescription

// This package tests the exact Foundation-only source compiled by the iOS app.
// It deliberately has no Firebase, UIKit or external package dependencies.
let package = Package(
    name: "LeagueDexARAMCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "ARAMCore", targets: ["ARAMCore"]),
        .library(name: "SyncCore", targets: ["SyncCore"]),
        .library(name: "CompanionCore", targets: ["CompanionCore"])
    ],
    targets: [
        .target(name: "ARAMCore", path: "LeagueDex/ARAMCore"),
        .testTarget(name: "ARAMCoreTests", dependencies: ["ARAMCore"], path: "Tests/ARAMCoreTests"),
        .target(name: "SyncCore", path: "LeagueDex/SyncCore"),
        .testTarget(name: "SyncCoreTests", dependencies: ["SyncCore"], path: "Tests/SyncCoreTests"),
        .target(name: "CompanionCore", path: "LeagueDex/CompanionCore"),
        .testTarget(name: "CompanionCoreTests", dependencies: ["CompanionCore"], path: "Tests/CompanionCoreTests")
    ]
)
