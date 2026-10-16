// swift-tools-version: 6.0
import PackageDescription

// Native unit tests for the two small pure-Swift utilities used by LeagueDex.
let package = Package(
    name: "LeagueDexCore",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "ARAMCore", path: "LeagueDex/ARAMCore"),
        .testTarget(name: "ARAMCoreTests", dependencies: ["ARAMCore"], path: "Tests/ARAMCoreTests")
    ]
)
