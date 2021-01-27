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

extension Notification {
    var sanitizedUserInfo: [String: Any] {
        .init(uniqueKeysWithValues: (self.userInfo ?? [:]).map { ($0.key.description, $0.value) })
    }
}

public struct ContextDidSaveNotification {
    public init(note: Notification) {
        guard note.name == .NSManagedObjectContextDidSave else { fatalError() }
        notification = note
    }
    
    public var insertedObjects: AnyIterator<NSManagedObject> {
        iterator(forKey: NSInsertedObjectsKey)
    }
    
    public var updatedObjects: AnyIterator<NSManagedObject> {
        iterator(forKey: NSUpdatedObjectsKey)
    }
    
    public var deletedObjects: AnyIterator<NSManagedObject> {
        iterator(forKey: NSDeletedObjectsKey)
    }
    
    public var managedObjectContext: NSManagedObjectContext {
        guard let c = notification.object as? NSManagedObjectContext else { fatalError("Invalid notification object") }
        return c
    }
    
    public var userInfo: [String: Any] { self.notification.sanitizedUserInfo }
    
    // MARK: Private
    
    fileprivate let notification: Notification
    
    private func iterator(forKey key: String) -> AnyIterator<NSManagedObject> {
        guard let set = self.userInfo[key] as? NSSet else {
            return AnyIterator { nil }
        }
        var innerIterator = set.makeIterator()
        return AnyIterator { return innerIterator.next() as? NSManagedObject }
    }
}

extension ContextDidSaveNotification: CustomDebugStringConvertible {
    public var debugDescription: String {
        var components = [notification.name.rawValue]
        components.append(managedObjectContext.description)
        for (name, set) in [("inserted", insertedObjects), ("updated", updatedObjects), ("deleted", deletedObjects)] {
            let all = set.map { $0.objectID.description }.joined(separator: ", ")
            components.append("\(name): {\(all)})")
        }
        return components.joined(separator: " ")
    }
}

public struct ContextDidSaveObjectIDsNotification {
    public init(note: Notification) {
        assert(note.name == .NSManagedObjectContextDidSaveObjectIDs)
        notification = note
    }
    
    public var insertedObjectIDs: Set<NSManagedObjectID> {
        objects(forKey: NSInsertedObjectIDsKey)
    }
    
    public var updatedObjectIDs: Set<NSManagedObjectID> {
        objects(forKey: NSUpdatedObjectIDsKey)
    }
    
    public var deletedObjectIDs: Set<NSManagedObjectID> {
        objects(forKey: NSDeletedObjectIDsKey)
    }
    
    public var refreshedObjectIDs: Set<NSManagedObjectID> {
        objects(forKey: NSRefreshedObjectIDsKey)
    }
    
    public var invalidatedObjectIDs: Set<NSManagedObjectID> {
        objects(forKey: NSInvalidatedObjectIDsKey)
    }
    
    public var userInfo: [String: Any] { self.notification.sanitizedUserInfo }
    
    // MARK: Private
    
    private let notification: Notification
    
    private func objects(forKey key: String) -> Set<NSManagedObjectID> {
        return (self.userInfo[key] as? Set<NSManagedObjectID>) ?? Set()
    }
}


public struct ContextWillSaveNotification {
    public init(note: Notification) {
        assert(note.name == .NSManagedObjectContextWillSave)
        notification = note
    }
    
    public var managedObjectContext: NSManagedObjectContext {
        guard let c = notification.object as? NSManagedObjectContext else { fatalError("Invalid notification object") }
        return c
    }
    
    public var userInfo: [String: Any] { self.notification.sanitizedUserInfo }
    
    // MARK: Private
    
    private let notification: Notification
}

public struct ObjectsDidChangeNotification {
    init(note: Notification) {
        assert(note.name == .NSManagedObjectContextObjectsDidChange)
        notification = note
    }
    
    public var insertedObjects: Set<NSManagedObject> {
        objects(forKey: NSInsertedObjectsKey)
    }
    
    public var updatedObjects: Set<NSManagedObject> {
        objects(forKey: NSUpdatedObjectsKey)
    }
    
    public var deletedObjects: Set<NSManagedObject> {
        objects(forKey: NSDeletedObjectsKey)
    }
    
    public var refreshedObjects: Set<NSManagedObject> {
        objects(forKey: NSRefreshedObjectsKey)
    }
    
    public var invalidatedObjects: Set<NSManagedObject> {
        objects(forKey: NSInvalidatedObjectsKey)
    }
    
    public var invalidatedAllObjects: Bool {
        self.userInfo[NSInvalidatedAllObjectsKey] != nil
    }
    
    public var queryGenerationToken: NSQueryGenerationToken? {
        self.userInfo[NSManagedObjectContextQueryGenerationKey] as? NSQueryGenerationToken
    }
    
    public var wasMerge: Bool {
        // N.B.: This key is not documented, it's used internally by Core Data
        // for exactly this purpose (detecting merges to avoid model->view->model
        // change notification loops). A different solution would be advisable
        // when available.
        self.userInfo["NSObjectsChangedByMergeChangesKey"] != nil
    }
    
    public var managedObjectContext: NSManagedObjectContext {
        guard let c = notification.object as? NSManagedObjectContext else { fatalError("Invalid notification object") }
        return c
    }
    
    public var userInfo: [String: Any] { self.notification.sanitizedUserInfo }
    
    // MARK: Private
    
    private let notification: Notification
    
    private func objects(forKey key: String) -> Set<NSManagedObject> {
        return (self.userInfo[key] as? Set<NSManagedObject>) ?? Set()
    }
}

extension NSManagedObjectContext {
    
    /// Adds the given block to the given `NotificationCenter`'s dispatch table for the given context's did-save notifications.
    /// - returns: An opaque object to act as the observer. This must be sent to the given `NotificationCenter`'s `removeObserver()`.
    public func addContextDidSaveNotificationObserver(to nc: NotificationCenter = .default, _ handler: @escaping (ContextDidSaveNotification) -> ()) -> NSObjectProtocol {
        return nc.addObserver(forName: .NSManagedObjectContextDidSave, object: self, queue: nil) { note in
            let wrappedNote = ContextDidSaveNotification(note: note)
            handler(wrappedNote)
        }
    }
    
    /// Adds the given block to the given `NotificationCenter`'s dispatch table for the given context's did-save-object-IDs notifications.
    /// - returns: An opaque object to act as the observer. This must be sent to the given `NotificationCenter`'s `removeObserver()`.
    public func addContextDidSaveObjectIDsNotificationObserver(to nc: NotificationCenter = .default, _ handler: @escaping (ContextDidSaveObjectIDsNotification) -> ()) -> NSObjectProtocol {
        return nc.addObserver(forName: .NSManagedObjectContextDidSaveObjectIDs, object: self, queue: nil) { note in
            let wrappedNote = ContextDidSaveObjectIDsNotification(note: note)
            handler(wrappedNote)
        }
    }
    
    /// Adds the given block to the given `NotificationCenter`'s dispatch table for the given context's will-save notifications.
    /// - returns: An opaque object to act as the observer. This must be sent to the given `NotificationCenter`'s `removeObserver()`.
    public func addContextWillSaveNotificationObserver(to nc: NotificationCenter = .default, _ handler: @escaping (ContextWillSaveNotification) -> ()) -> NSObjectProtocol {
        return nc.addObserver(forName: .NSManagedObjectContextWillSave, object: self, queue: nil) { note in
            let wrappedNote = ContextWillSaveNotification(note: note)
            handler(wrappedNote)
        }
    }
    
    /// Adds the given block to the given `NotificationCenter`'s dispatch table for the given context's objects-did-change notifications.
    /// - returns: An opaque object to act as the observer. This must be sent to the given `NotificationCenter`'s `removeObserver()`.
    public func addObjectsDidChangeNotificationObserver(to nc: NotificationCenter = .default, _ handler: @escaping (ObjectsDidChangeNotification) -> ()) -> NSObjectProtocol {
        return nc.addObserver(forName: .NSManagedObjectContextObjectsDidChange, object: self, queue: nil) { note in
            let wrappedNote = ObjectsDidChangeNotification(note: note)
            handler(wrappedNote)
        }
    }
    
    public func performMergeChanges(from note: ContextDidSaveNotification) {
        perform {
            self.mergeChanges(fromContextDidSave: note.notification)
        }
    }
}
