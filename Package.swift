// swift-tools-version:5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RandomDungeonGenerator",
    platforms: [
        .macOS(.v11),
        .iOS(.v14),
        .tvOS(.v14)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "RandomDungeonGenerator",
            targets: ["RandomDungeonGenerator"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/nicklockwood/SwiftFormat.git", from: "0.47.7"),
        
//        .package(url: "https://github.com/RedECSEngine/Geometry.git", from: "0.0.5"),
        .package(path: "../Geometry"),

//        .package(url: "https://github.com/RedECSEngine/Graphs.git", from: "0.0.1"),
        .package(path: "../swift-graphs"),
        
        .package(url: "https://github.com/RedECSEngine/Randomization.git", exact: "0.0.1")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "RandomDungeonGenerator",
            dependencies: [
                "Geometry",
                .product(name: "Graphs", package: "swift-graphs"),
                .product(name: "Randomization", package: "Randomization")
            ]
        ),
        .testTarget(
            name: "RandomDungeonGeneratorTests",
            dependencies: ["RandomDungeonGenerator"]
        ),
    ]
)
