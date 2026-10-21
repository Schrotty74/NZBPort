// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NZBRelay",
    defaultLocalization: "en",
    platforms: [.macOS("26.0")],
    products: [.executable(name: "NZBRelay", targets: ["NZBRelay"])],
    targets: [
        .target(name: "RelayCore", resources: [.process("Resources")]),
        .executableTarget(name: "NZBRelay", dependencies: ["RelayCore"]),
        .testTarget(name: "RelayCoreTests", dependencies: ["RelayCore"]),
        .testTarget(name: "NZBRelayTests", dependencies: ["NZBRelay", "RelayCore"])
    ],
    swiftLanguageModes: [.v6]
)
