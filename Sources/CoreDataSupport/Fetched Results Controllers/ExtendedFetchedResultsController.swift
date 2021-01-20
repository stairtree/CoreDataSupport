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

/// A FetchedResultsController that will also observe relationship's properties and report those changes via its delegate
///
/// Inspired by https://www.avanderlee.com/swift/nsfetchedresultscontroller-observe-relationship-changes/
public final class ExtendedFetchedResultsController<EntityType: NSFetchRequestResult>: WrappedNSFetchedResultsController<EntityType> {

    /// Observes relationship key paths and refreshes Core Data objects accordingly once the related managed object context saves.
    private var contextObserver: ManagedObjectContextObserver!
    /// Accumulated object IDs inbetween context saves that need to be refreshed.
    private var updatedObjectIDs: Set<NSManagedObjectID> = []
    
    public init(managedObjectContext context: NSManagedObjectContext, fetchRequest: ExtendedFetchRequest<EntityType>, sectionNameKeyPath: String? = nil, cacheName: String? = nil, notificationCenter nc: NotificationCenter = .default) {
        super.init(managedObjectContext: context, fetchRequest: fetchRequest.request, sectionNameKeyPath: sectionNameKeyPath, cacheName: cacheName)
        contextObserver = ManagedObjectContextObserver(moc: context, notificationCenter: nc) { [unowned self] change in
            self.handleContextChange(change, forKeyPaths: fetchRequest.keyPaths)
        }
    }
    
    private func handleContextChange(_ change: ManagedObjectContextObserver.ChangeType, forKeyPaths keyPaths: Set<RelationshipKeyPath>) {
        switch change {
        case .didChange(let note):
            let updatedObjectIDs = note.updatedObjects.updatedObjectIDs(for: keyPaths)
            self.updatedObjectIDs = self.updatedObjectIDs.union(updatedObjectIDs)
        case .willSave(_): ()
        case .didSave(_):
            guard !updatedObjectIDs.isEmpty else { return }
            guard let fetchedObjects = self.fetchedObjects as? [NSManagedObject], !fetchedObjects.isEmpty else { return }
            fetchedObjects.forEach { object in
                guard updatedObjectIDs.contains(object.objectID) else { return }
                object.refresh()
            }
            updatedObjectIDs.removeAll()
        case .didSaveObjectIDs(_): ()
        }
    }
}

/// An `NSFetchRequest` that includes relationship keypaths.
public struct ExtendedFetchRequest<ResultType: NSFetchRequestResult> {

    /// The underlying `NSFetchRequest`
    public let request: NSFetchRequest<ResultType>
    /// The extracted and parsed keyPaths from the enhanced fetch request.
    public let keyPaths: Set<RelationshipKeyPath>
    
    internal init(request: NSFetchRequest<ResultType>, relationshipKeyPaths: Set<String>) {
        self.request = request
        let relationships = request.entity!.relationshipsByName
        self.keyPaths = Set(relationshipKeyPaths.map { keyPath in
            RelationshipKeyPath(keyPath: keyPath, relationships: relationships)
        })
    }
}

/// Describes a relationship key path for a Core Data entity.
public struct RelationshipKeyPath: Hashable {

    /// The source property name of the relationship entity we're observing.
    let sourcePropertyName: String

    /// The name of the entity on the relation's destination side
    let destinationEntityName: String

    /// The destination property name we're observing
    let destinationPropertyName: String

    /// The inverse property name of this relationship. Can be used to get the affected object IDs.
    let inverseRelationshipKeyPath: String

    public init(keyPath: String, relationships: [String: NSRelationshipDescription]) {
        let keyPathComponents = keyPath.split(separator: ".", omittingEmptySubsequences: true)
        sourcePropertyName = String(keyPathComponents.first!)
        destinationPropertyName = String(keyPathComponents.last!)

        let relationship = relationships[sourcePropertyName]!
        destinationEntityName = relationship.destinationEntity!.name!
        inverseRelationshipKeyPath = relationship.inverseRelationship!.name

        assert(!destinationEntityName.isEmpty, "Invalid key path '\(keyPath)'. (Empty destination entity name)")
    }
}

extension Set where Element: NSManagedObject {

    /// Iterates over the objects and returns the object IDs that matched our observing keyPaths.
    /// - Parameter keyPaths: The keyPaths to observe changes for.
    fileprivate func updatedObjectIDs(for keyPaths: Set<RelationshipKeyPath>) -> Set<NSManagedObjectID> {
        var objectIDs: Set<NSManagedObjectID> = []
        forEach { object in
            guard let changedRelationshipKeyPath = object.changedKeyPath(from: keyPaths) else { return }

            let value = object.value(forKey: changedRelationshipKeyPath.inverseRelationshipKeyPath)
            if let toManyObjects = value as? Set<NSManagedObject> {
                toManyObjects.forEach {
                    objectIDs.insert($0.objectID)
                }
            } else if let toOneObject = value as? NSManagedObject {
                objectIDs.insert(toOneObject.objectID)
            } else {
                assertionFailure("Invalid relationship observed for keyPath: \(changedRelationshipKeyPath)")
                return
            }
        }
        return objectIDs
    }
}

private extension NSManagedObject {

    /// Matches the given key paths to the current changes of this `NSManagedObject`.
    /// - Parameter keyPaths: The key paths to match the changes for.
    /// - Returns: The matching relationship key path if found. Otherwise, `nil`.
    func changedKeyPath(from keyPaths: Set<RelationshipKeyPath>) -> RelationshipKeyPath? {
        return keyPaths.first { keyPath -> Bool in
            guard keyPath.destinationEntityName == entity.name! || keyPath.destinationEntityName == entity.superentity?.name else { return false }
            return changedValues().keys.contains(keyPath.destinationPropertyName)
        }
    }
}
