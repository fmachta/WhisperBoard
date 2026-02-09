// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WhisperBoard",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "WhisperBoard",
            targets: ["WhisperBoard"]
        ),
    ],
    dependencies: [
        // WhisperKit - On-device speech recognition
        .package(url: "https://github.com/argmaxinc/WhisperKit", from: "0.1.0"),
        // KeyboardKit - Keyboard extension helpers
        .package(url: "https://github.com/KeyboardKit/KeyboardKit", from: "13.0.0"),
    ],
    targets: [
        .target(
            name: "WhisperBoard",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit"),
                .product(name: "KeyboardKit", package: "KeyboardKit"),
            ]
        ),
    ]
)