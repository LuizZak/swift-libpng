// swift-tools-version:5.4
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
        .systemLibrary(
            name: "CLibPNG",
            pkgConfig: "libpng",
            providers: [.apt(["libpng-dev"]), .brew(["libpng"])]
        ),
        .target(
            name: "LibPNG",
            dependencies: ["CLibPNG"]),
        .testTarget(
            name: "LibPNGTests",
            dependencies: ["LibPNG"],
            exclude: [
                "TestResources/bl-getting-started-1.png"
            ]),
    ]
)
