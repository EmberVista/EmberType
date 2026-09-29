// swift-tools-version:5.9
// Dev-only test harness for EmberType's dictation text pipeline.
// Sources/ETHarness symlinks the app's real source files, so tests run the
// shipped code, not a copy. See DevHarness/README.md.
import PackageDescription

let package = Package(
    name: "ETHarness",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio", revision: "ddee663c4a9806d4f139943b0978b0f0a961587b"),
    ],
    targets: [
        .executableTarget(
            name: "ETHarness",
            dependencies: [.product(name: "FluidAudio", package: "FluidAudio")]
        ),
        .executableTarget(name: "ETDriver"),
        .testTarget(name: "ETHarnessTests", dependencies: ["ETHarness"]),
    ]
)
