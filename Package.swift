// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "LibPNG",
    products: [
        .library(
            name: "LibPNG",
            targets: ["LibPNG"]),
        .library(
            name: "CLibPNG",
            targets: ["CLibPNG"]),
    ],
    targets: [
        .target(
            name: "CLibPNG",
            linkerSettings: [
                .linkedLibrary("z")
            ]),
        .target(
            name: "LibPNG",
            dependencies: ["CLibPNG"]),
        .testTarget(
            name: "LibPNGTests",
            dependencies: ["LibPNG"]),
    ]
)
