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

extension NSManagedObjectContext {
    /// The first store of the persistent store coordinator
    private var store: NSPersistentStore {
        guard let psc = persistentStoreCoordinator else { fatalError("PSC missing") }
        guard let store = psc.persistentStores.first else { fatalError("No Store") }
        return store
    }
    
    /// The metadata dictionary for the first store of the persistent store coordinator
    public var metaData: [String: AnyObject] {
        get {
            guard let psc = persistentStoreCoordinator else { fatalError("must have PSC") }
            return psc.metadata(for: store) as [String: AnyObject]
        }
        set {
            performChanges {
                guard let psc = self.persistentStoreCoordinator else { fatalError("PSC missing") }
                psc.setMetadata(newValue, for: self.store)
            }
        }
    }
    
    /// Add metadata to the persistent store
    public func setMetaData(object: AnyObject?, forKey key: String) {
        var md = metaData
        md[key] = object
        metaData = md
    }
    
    public func insertObject<A: NSManagedObject>() -> A where A: Managed {
        guard let obj = NSEntityDescription.insertNewObject(forEntityName: A.entityName, into: self) as? A else { fatalError("Wrong object type") }
        return obj
    }
    
    /// Try to save the context, and automatically roll back on errors.
    /// - Returns: `true` if the save succeeded, `false` on error/rollback.
    public func saveOrRollback() -> Bool {
        do {
            try save()
            return true
        } catch {
            Logger(label: "Core Data").warning("Failed to save context\(name.map { " '\($0)'" } ?? ""): \(error)")
            rollback()
            return false
        }
    }
    
    /// Perform a `saveOrRollback` asynchronously on the context
    public func performSaveOrRollback() {
        perform {
            _ = self.saveOrRollback()
        }
    }
    
    /// Asynchronously perform changes on the context's queue and save them (or roll back on error)
    /// - Parameter block: The changes to perform and save asynchronously
    public func performChanges(block: @escaping () -> ()) {
        perform {
            block()
            _ = self.saveOrRollback()
        }
    }
}

// See https://oleb.net/blog/2018/02/performandwait/
extension NSManagedObjectContext {
    /// An improved version of `performAndWait` that can return a value synchronously.
    func performAndWait<T>(_ block: () throws -> T) throws -> T {
        var result: Result<T, Error>?
        performAndWait {
            result = Result { try block() }
        }
        return try result!.get()
    }

    /// An improved version of `performAndWait` that can return a value synchronously.
    func performAndWait<T>(_ block: () -> T) -> T {
        var result: T?
        performAndWait {
            result = block()
        }
        return result!
    }
}

// See: https://www.cocoawithlove.com/2008/08/safely-fetching-nsmanagedobject-by-uri.html
extension NSManagedObjectContext {
    /// Fetch the object identified by `uri` in the current context
    ///
    /// - Parameter uri: The `uri` for the object to fetch
    /// - Returns: The fetched object, or `nil` if it wasn't found
    public func object(withURI uri: URL) -> NSManagedObject? {
        guard let psc = persistentStoreCoordinator else { return nil }
        guard let objectID = psc.managedObjectID(forURIRepresentation: uri) else { return nil }
        
        let objectForID = object(with: objectID)
        
        if !objectForID.isFault { return objectForID }
        
        let request = NSFetchRequest<NSFetchRequestResult>()
        request.entity = objectID.entity
        
        // Equivalent to
        // predicate = [NSPredicate predicateWithFormat:@"SELF = %@", objectForID];
        let predicate = NSComparisonPredicate(
            leftExpression: NSExpression.expressionForEvaluatedObject(),
            rightExpression: NSExpression(forConstantValue: objectForID),
            modifier: NSComparisonPredicate.Modifier.direct,
            type: NSComparisonPredicate.Operator.equalTo,
            options: [])
        
        request.predicate = predicate
        
        let result = try? fetch(request)
        return result?.first as? NSManagedObject
    }
}


// MARK: - Single Object Cache

/// The key under which the cache for singletons is stored in the store's metadata
private let SingleObjectCacheKey = "SingleObjectCache"
/// The cache itself is a dictionary holding managed objects
private typealias SingleObjectCache = [String: NSManagedObject]

extension NSManagedObjectContext {
    
    /// Cache a singleton object in the `userInfo` of the current context
    /// - Parameters:
    ///   - object: The singleton to store
    ///   - key: The key under which to store the object
    public func set(_ object: NSManagedObject?, forSingleObjectCacheKey key: String) {
        var cache = userInfo[SingleObjectCacheKey] as? SingleObjectCache ?? [:]
        cache[key] = object
        userInfo[SingleObjectCacheKey] = cache
    }
    
    /// Retrieve a singleton from the `userInfo` of the current context
    /// - Parameter key: The key under which the singleton was stored
    /// - Returns: The object if it was cached, or `nil`
    public func object(forSingleObjectCacheKey key: String) -> NSManagedObject? {
        guard let cache = userInfo[SingleObjectCacheKey] as? [String: NSManagedObject] else { return nil }
        return cache[key]
    }
}
