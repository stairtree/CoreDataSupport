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

import CoreData
import Logging

public func migrateStore<Version: ModelVersion>(from sourceURL: URL, to targetURL: URL, targetVersion: Version, deleteSource: Bool = false, progress: Progress? = nil, logger: Logger = Logger(label: "Core Data")) {
    guard let sourceVersion = Version(storeURL: sourceURL) else { fatalError("unknown store version at URL \(sourceURL)") }
    var currentURL = sourceURL
    let migrationSteps = sourceVersion.migrationSteps(to: targetVersion)
    let migrationProgress = progress.map {
        Progress(totalUnitCount: Int64(migrationSteps.count), parent: $0, pendingUnitCount: $0.totalUnitCount)
    }
    for step in migrationSteps {
        migrationProgress?.becomeCurrent(withPendingUnitCount: 1)
        let manager = NSMigrationManager(sourceModel: step.source, destinationModel: step.destination)
        migrationProgress?.resignCurrent()
        let destinationURL = URL(fileURLWithPath:NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString)
        for mapping in step.mappings {
            do {
                try manager.migrateStore(from: currentURL,
                                         sourceType: NSSQLiteStoreType,
                                         options: nil,
                                         with: mapping,
                                         toDestinationURL: destinationURL,
                                         destinationType: NSSQLiteStoreType,
                                         destinationOptions: nil)
            } catch {
                logger.error("Failed to migrate store from \(currentURL.absoluteString) to \(destinationURL.absoluteString): \(error)")
            }
        }
        if currentURL != sourceURL {
            NSPersistentStoreCoordinator.destroyStore(at: currentURL)
        }
        currentURL = destinationURL
    }
    try! NSPersistentStoreCoordinator.replaceStore(at: targetURL, withStoreAt: currentURL)
    if (currentURL != sourceURL) {
        NSPersistentStoreCoordinator.destroyStore(at: currentURL)
    }
    if (targetURL != sourceURL && deleteSource) {
        NSPersistentStoreCoordinator.destroyStore(at: sourceURL)
    }
}
