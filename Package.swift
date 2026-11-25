// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DesktopKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DesktopKit", targets: ["DesktopKit"]),
    ],
    targets: [
        .target(name: "DesktopKit"),
        .testTarget(name: "DesktopKitTests", dependencies: ["DesktopKit"]),
    ]
)
