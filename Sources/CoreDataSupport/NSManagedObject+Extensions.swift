//  Created by Florian on 19/09/15.
//  Copyright © 2015 objc.io. All rights reserved.

import CoreData


extension NSManagedObject {
    public func refresh(_ mergeChanges: Bool = true) {
        managedObjectContext?.refresh(self, mergeChanges: mergeChanges)
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
    public func remap(to context: NSManagedObjectContext) -> [Iterator.Element] {
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
