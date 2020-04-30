// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "CoreDataSupport",
    platforms: [
        .macOS(.v10_14)
    ],
    products: [
        .library(
            name: "CoreDataSupport",
            targets: ["CoreDataSupport"]),
    ],
    dependencies: [
         .package(url: "git@gitlab.com:stairtree/frameworks/Utilities.git", .branch("master")),
    ],
    targets: [
        .target(
            name: "CoreDataSupport",
            dependencies: ["Utilities"]),
        .testTarget(
            name: "CoreDataSupportTests",
            dependencies: ["CoreDataSupport"]),
    ]
)
