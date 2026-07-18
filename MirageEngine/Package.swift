// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Mirage",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1),
        .macCatalyst(.v17)
    ],
    products: [
        .library(name: "Mirage", targets: ["Mirage"])
    ],
    targets: [
        .binaryTarget(
            name: "sdcpp",
            path: "Frameworks/sdcpp.xcframework"
        ),
        .target(
            name: "Mirage",
            dependencies: ["sdcpp"],
            path: "Sources/Mirage"
        )
    ]
)
