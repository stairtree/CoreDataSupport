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

public final class ManagedObjectObserver {
    public enum ChangeType {
        case delete
        case update
    }
    
    private let notificationCenter: NotificationCenter
    
    public init?(object: Managed, notificationCenter nc: NotificationCenter = .default, changeHandler: @escaping (ChangeType) -> ()) {
        guard let moc = object.managedObjectContext else { return nil }
        self.notificationCenter = nc
        objectHasBeenDeleted = !type(of: object).defaultPredicate.evaluate(with: object)
        token = moc.addObjectsDidChangeNotificationObserver(to: nc) { [unowned self] note in
            guard let changeType = self.changeType(of: object, in: note) else { return }
            self.objectHasBeenDeleted = changeType == .delete
            changeHandler(changeType)
        }
    }
    
    deinit {
        token.map { notificationCenter.removeObserver($0) }
    }
    
    // MARK: Private
    
    fileprivate var token: NSObjectProtocol!
    fileprivate var objectHasBeenDeleted: Bool = false
    
    fileprivate func changeType(of object: Managed, in note: ObjectsDidChangeNotification) -> ChangeType? {
        let deleted = note.deletedObjects.union(note.invalidatedObjects)
        if note.invalidatedAllObjects || deleted.contains(where: { $0 === object }) {
            return .delete
        }
        let updated = note.updatedObjects.union(note.refreshedObjects)
        if updated.contains(where: { $0 === object }) {
            let predicate = type(of: object).defaultPredicate
            if predicate.evaluate(with: object) {
                return .update
            } else if !objectHasBeenDeleted {
                return .delete
            }
        }
        return nil
    }
}
