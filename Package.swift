// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Soundcheck",
    platforms: [.macOS("14.2")],
    products: [.executable(name: "Soundcheck", targets: ["Mixer"])],
    targets: [
        .target(name: "AudioRender", publicHeadersPath: "include"),
        .executableTarget(name: "Mixer", dependencies: ["AudioRender"], resources: [.copy("Resources")])
    ]
)
