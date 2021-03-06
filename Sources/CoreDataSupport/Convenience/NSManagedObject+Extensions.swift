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

extension NSManagedObject {
    public func refresh(mergeChanges: Bool = true) {
        managedObjectContext?.refresh(self, mergeChanges: mergeChanges)
    }
    
    public func remapped(to context: NSManagedObjectContext) -> Self? {
        guard let fromContext = managedObjectContext else { return nil }
        guard fromContext !== context else { return self }
        
        if objectID.isTemporaryID {
            do { try fromContext.obtainPermanentIDs(for: [self]) }
            catch {
                Logger(label: "Core Data").error("Failed to obtain permanent object ID: \(error)")
                return nil
            }
        }
        
        do {
            let objectInTargetContext = try context.existingObject(with: objectID) as? Self
            return objectInTargetContext
        } catch {
            Logger(label: "Core Data").error("Failed to fetch existing object: \(error)")
            return nil
        }
    }
}

extension NSManagedObject {
    public func changedValue(forKey key: String) -> Any? {
        return changedValues()[key]
    }
    public func committedValue(forKey key: String) -> Any? {
        return committedValues(forKeys: [key])[key]
    }
}

extension Sequence where Iterator.Element: NSManagedObject {
    public func remapped(to context: NSManagedObjectContext) -> [Iterator.Element] {
        return map { unmappedMO in
            guard unmappedMO.managedObjectContext !== context else { return unmappedMO }
            guard let object = context.object(with: unmappedMO.objectID) as? Iterator.Element else { fatalError("Invalid object type") }
            return object
        }
    }
}

extension Collection where Iterator.Element: NSManagedObject {
    public func fetchFaults() {
        guard !self.isEmpty else { return }
        guard let context = self.first?.managedObjectContext else { fatalError("Managed object must have context") }
        let faults = self.filter { $0.isFault }
        guard let object = faults.first else { return }
        let request = NSFetchRequest<Iterator.Element>()
        request.entity = object.entity
        request.returnsObjectsAsFaults = false
        request.predicate = NSPredicate(format: "self in %@", faults)
        let _ = try! context.fetch(request)
    }
}
