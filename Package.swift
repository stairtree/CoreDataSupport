// swift-tools-version:5.2
//===----------------------------------------------------------------------===//
//
// This source file is part of the Core Data Support open source project
//
// Copyright (c) Stairtree GmbH
// Licensed under the MIT license
//
// See LICENSE.txt and LICENSE.objc.io.txt for license information
//
// SPDX-License-Identifier: MIT
//
//===----------------------------------------------------------------------===//

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
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.4.0"),
    ],
    targets: [
        .target(
            name: "CoreDataSupport",
            dependencies: [.product(name: "Logging", package: "swift-log")]),
        .testTarget(
            name: "CoreDataSupportTests",
            dependencies: ["CoreDataSupport"]),
    ]
)
