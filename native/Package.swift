// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HelmNative",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Helm", targets: ["HelmNative"])],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", exact: "1.15.0")
    ],
    targets: [
        .executableTarget(
            name: "HelmNative",
            dependencies: [.product(name: "SwiftTerm", package: "SwiftTerm")],
            path: "Sources/HelmNative",
            exclude: ["Resources"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(name: "HelmNativeTests", dependencies: ["HelmNative"])
    ]
)
