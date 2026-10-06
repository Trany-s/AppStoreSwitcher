// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppStoreSwitcher",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "AppStoreSwitcher", targets: ["AppStoreSwitcher"])
    ],
    targets: [
        .executableTarget(
            name: "AppStoreSwitcher",
            path: "Sources/AppStoreSwitcher"
        )
    ]
)
