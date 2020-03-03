// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "CoreDataSupport",
    platforms: [
        .macOS(.v10_13)
    ],
    products: [
        .library(
            name: "CoreDataSupport",
            targets: ["CoreDataSupport"]),
    ],
    dependencies: [
         .package(url: "git@gitlab.com:stairtree/frameworks/Utilities.git", from: "3.0.0"),
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
