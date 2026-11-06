// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "AgentOfficeKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "AgentOfficeKit",
            targets: ["AgentOfficeKit"]
        ),
    ],
    targets: [
        .target(
            name: "AgentOfficeKit",
            resources: [.process("Localizable.xcstrings")]
        ),
        .testTarget(
            name: "AgentOfficeKitTests",
            dependencies: ["AgentOfficeKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
