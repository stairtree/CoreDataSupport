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

extension NSPersistentStoreCoordinator {
    public static func destroyStore(at url: URL) {
        do {
            let psc = self.init(managedObjectModel: NSManagedObjectModel())
            try psc.destroyPersistentStore(at: url, ofType: NSSQLiteStoreType, options: nil)
        } catch {
            Logger(label: "Core Data").warning("failed to destroy persistent store at \(url): \(error)")
        }
    }
    
    public static func replaceStore(at targetURL: URL, withStoreAt sourceURL: URL) throws {
        let psc = self.init(managedObjectModel: NSManagedObjectModel())
        try psc.replacePersistentStore(at: targetURL, destinationOptions: nil, withPersistentStoreFrom: sourceURL, sourceOptions: nil, ofType: NSSQLiteStoreType)
    }
}

