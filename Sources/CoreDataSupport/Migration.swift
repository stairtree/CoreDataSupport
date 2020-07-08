//  Created by Florian on 06/10/15.
//  Copyright © 2015 objc.io. All rights reserved.

import CoreData

public func migrateStore<Version: ModelVersion>(from sourceURL: URL, to targetURL: URL, targetVersion: Version, deleteSource: Bool = false, progress: Progress? = nil) {
    guard let sourceVersion = Version(storeURL: sourceURL) else { fatalError("unknown store version at URL \(sourceURL)") }
    var currentURL = sourceURL
    let migrationSteps = sourceVersion.migrationSteps(to: targetVersion)
    var migrationProgress: Progress?
    if let p = progress {
        if #available(OSX 10.11, *) {
            migrationProgress = Progress(totalUnitCount: Int64(migrationSteps.count), parent: p, pendingUnitCount: p.totalUnitCount)
        } else {
            // FIXME: This doesn't work probably
            p.becomeCurrent(withPendingUnitCount: Int64(migrationSteps.count))
        }
    }
    for step in migrationSteps {
        migrationProgress?.becomeCurrent(withPendingUnitCount: 1)
        let manager = NSMigrationManager(sourceModel: step.source, destinationModel: step.destination)
        migrationProgress?.resignCurrent()
        let destinationURL = URL.temporary
        for mapping in step.mappings {
            do {
                try manager.migrateStore(from: currentURL,
                                         sourceType: NSSQLiteStoreType,
                                         options: nil,
                                         with: mapping,
                                         toDestinationURL: destinationURL,
                                         destinationType: NSSQLiteStoreType,
                                         destinationOptions: nil)
            } catch let e {
                print(e)
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
