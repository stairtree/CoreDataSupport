// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "CoreDataSupport",
    platforms: [
        .macOS(.v10_14), .iOS(.v11), .watchOS(.v4), .tvOS(.v11)
    ],
    products: [
        .library(
            name: "CoreDataSupport",
            targets: ["CoreDataSupport"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "CoreDataSupport"),
        .testTarget(
            name: "CoreDataSupportTests",
            dependencies: ["CoreDataSupport"]),
    ]
)
