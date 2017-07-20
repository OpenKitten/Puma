// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Puma",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "Puma",
            targets: ["Puma"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
    .package(url: "https://github.com/OpenKitten/Lynx.git", .revision("master")),
    .package(url: "https://github.com/OpenKitten/Schrodinger.git", .revision("framework")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "Puma",
            dependencies: ["Lynx", "Schrodinger"]),
        .testTarget(
            name: "PumaTests",
            dependencies: ["Puma"]),
    ]
)
