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

#if os(macOS)

import AppKit
import CoreData

public protocol FetchedResultsControllerDelegate: AnyObject {
    func willChangeContent<T>(_ controller: WrappedNSFetchedResultsController<T>)
    func updateWithChange<T>(_ controller: WrappedNSFetchedResultsController<T>, change: WrappedNSFetchedResultsController<T>.ChangeType)
    func didChangeContent<T>(_ controller: WrappedNSFetchedResultsController<T>)
}

public class WrappedNSFetchedResultsController<EntityType: NSFetchRequestResult>: NSObject, NSFetchedResultsControllerDelegate {

    public enum ChangeType {
        case insert(object: EntityType, atIndex: Int)
        case update(object: EntityType, atIndex: Int, progressiveChangeIndex: Int)
        case move(object: EntityType, fromIndex: Int, toIndex: Int, progressiveChangeIndex: Int)
        case delete(object: EntityType, atIndex: Int, progressiveChangeIndex: Int)
    }

    private let realController: NSFetchedResultsController<EntityType>
    
    public init(managedObjectContext: NSManagedObjectContext, fetchRequest: NSFetchRequest<EntityType>, sectionNameKeyPath: String? = nil, cacheName: String? = nil) {
        self.realController = .init(fetchRequest: fetchRequest, managedObjectContext: managedObjectContext, sectionNameKeyPath: sectionNameKeyPath, cacheName: cacheName)
        super.init()
        self.realController.delegate = self
    }
    
    public weak var delegate: FetchedResultsControllerDelegate? = nil
    public var fetchedObjects: [EntityType] { self.realController.fetchedObjects ?? [] }
    public var arrangedObjects: [EntityType] { self.fetchedObjects }
    public var fetchRequest: NSFetchRequest<EntityType>? { self.realController.fetchRequest }
    public var filterPredicate: NSPredicate? {
        get { self.fetchRequest?.predicate }
        set { self.fetchRequest?.predicate = newValue }
    }
    public var sortDescriptors: [NSSortDescriptor]? {
        get { self.fetchRequest?.sortDescriptors }
        set { self.fetchRequest?.sortDescriptors = newValue }
    }
    
    public func performFetch() throws { try self.realController.performFetch() }
    
    public func controller(
        _ controller: NSFetchedResultsController<NSFetchRequestResult>,
        didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?
    ) {
        assert(controller == self.realController)
        switch type {
            case .insert:
                self.delegate?.updateWithChange(self, change: .insert(
                    object: anObject as! EntityType,
                    atIndex: newIndexPath!.first!
                ))
                
            case .move, .update:
                // The old implementation sent "update, move" for moves
                self.delegate?.updateWithChange(self, change: .update(
                    object: anObject as! EntityType,
                    atIndex: indexPath!.first!, // atIndex is IGNORED
                    progressiveChangeIndex: indexPath!.first! // pIndex is used as "index to reloadData at"
                ))
                
                if type == .move {
                    self.delegate?.updateWithChange(self, change: .move(
                        object: anObject as! EntityType,
                        fromIndex: indexPath!.first!, // fromIndex is IGNORED
                        toIndex: newIndexPath!.first!, // toIndex is used as "index moved to"
                        progressiveChangeIndex: indexPath!.first! // pIndex is used as "index moved from"
                    ))
                }
            case .delete:
                self.delegate?.updateWithChange(self, change: .delete(
                    object: anObject as! EntityType,
                    atIndex: indexPath!.first!, // atIndex is IGNORED
                    progressiveChangeIndex: indexPath!.first! // pIndex is used as "index to delete"
                ))
                
            @unknown default:
                fatalError("Don't know how to handle random new NSFRC actions, why isn't this thing @frozen?")
        }
    }
    
    public func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        assert(controller == self.realController)
        self.delegate?.willChangeContent(self)
    }
    
    public func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        assert(controller == self.realController)
        self.delegate?.didChangeContent(self)
    }
}

#endif
