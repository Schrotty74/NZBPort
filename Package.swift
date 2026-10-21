// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NZBRelay",
    platforms: [.macOS("26.0")],
    products: [.executable(name: "NZBRelay", targets: ["NZBRelay"])],
    targets: [
        .target(name: "RelayCore"),
        .executableTarget(name: "NZBRelay", dependencies: ["RelayCore"]),
        .testTarget(name: "RelayCoreTests", dependencies: ["RelayCore"])
    ],
    swiftLanguageModes: [.v6]
)
