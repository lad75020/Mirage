// swift-tools-version: 5.9
// Local vendored TensorFlow Lite C runtime (LiteRT) for on-device
// .tflite inference. Binary xcframework from the official Google
// TensorFlowLiteC 2.17.0 CocoaPods release.
import PackageDescription

let package = Package(
    name: "LiteRTRuntime",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "LiteRTRuntime",
            targets: ["LiteRTRuntime"]
        )
    ],
    targets: [
        .binaryTarget(
            name: "TensorFlowLiteC",
            path: "TensorFlowLiteC.xcframework"
        ),
        .target(
            name: "LiteRTRuntime",
            dependencies: ["TensorFlowLiteC"],
            path: "Sources/LiteRTRuntime"
        )
    ]
)
