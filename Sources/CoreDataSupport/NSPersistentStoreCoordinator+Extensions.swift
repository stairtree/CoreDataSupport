//
//  NSPersistentStoreCoordinator+Extensions2.swift
//  Migrations
//
//  Created by Florian on 06/10/15.
//  Copyright © 2015 objc.io. All rights reserved.
//

import CoreData


extension NSPersistentStoreCoordinator {
    // TODO(swift3) Migrate thise to NSPersistentContainer
    public static func destroyStore(at url: URL) {
        if #available(OSX 10.11, *) {
            do {
                let psc = self.init(managedObjectModel: NSManagedObjectModel())
                try psc.destroyPersistentStore(at: url, ofType: NSSQLiteStoreType, options: nil)
                
            } catch let e {
                print("failed to destroy persistent store at \(url)", e)
            }
        } else {
            // Fallback on earlier versions
            fatalError("Unimplemented for macOS < 10.11")
        }
    }
    
    // TODO(swift3) Migrate thise to NSPersistentContainer
    public static func replaceStore(at targetURL: URL, withStoreAt sourceURL: URL) throws {
        if #available(OSX 10.11, *) {
            let psc = self.init(managedObjectModel: NSManagedObjectModel())
            try psc.replacePersistentStore(at: targetURL, destinationOptions: nil, withPersistentStoreFrom: sourceURL, sourceOptions: nil, ofType: NSSQLiteStoreType)
        } else {
            // Fallback on earlier versions
            fatalError("Unimplemented for macOS < 10.11")
        }
    }
}

