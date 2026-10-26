// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PhoneBar",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "PhoneBar", targets: ["PhoneBar"])],
    targets: [
        .executableTarget(name: "PhoneBar", path: "Sources/PhoneBar")
    ]
)
