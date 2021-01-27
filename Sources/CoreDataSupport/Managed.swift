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

/// A common protocol for managed objects
///
/// Extending this protocol adds functionality to all NSManagedObject subclasses
public protocol Managed: AnyObject, NSFetchRequestResult {
    var managedObjectContext: NSManagedObjectContext? { get }
    static var entity: NSEntityDescription { get }
    static var entityName: String { get }
    static var defaultSortDescriptors: [NSSortDescriptor] { get }
    static var defaultPredicate: NSPredicate { get }
    static var defaultIncludesSubentities: Bool { get }
    static var defaultRelationshipKeyPathsForPrefetching: [String] { get }
}

extension Managed {
    public static var defaultSortDescriptors: [NSSortDescriptor] { [] }
    public static var defaultPredicate: NSPredicate { .init(value: true) }
    public static var defaultRelationshipKeyPathsForPrefetching: [String] { [] }
}

extension Managed {
    /// A fetch request for the entity leveraging the `defaultPredicate` and the `defaultPredicate` among the other default attributes
    public static var sortedFetchRequest: NSFetchRequest<Self> {
        let request = NSFetchRequest<Self>(entityName: entityName)
        request.sortDescriptors = defaultSortDescriptors
        request.predicate = defaultPredicate
        request.includesSubentities = defaultIncludesSubentities
        request.relationshipKeyPathsForPrefetching = defaultRelationshipKeyPathsForPrefetching
        return request
    }
    /// A default fetch request using a custom predicate in addition to the default predicate
    public static func sortedFetchRequest(with predicate: NSPredicate) -> NSFetchRequest<Self> {
        let request = sortedFetchRequest
        // The `sortedFetchRequest` already contains the default predicate but instead
        // of checking if there even is a predicate, it's easier to just set it again.
        request.predicate = Self.predicate(predicate)
        return request
    }
    /// Creates a merged pedicate with the default predicate of the entity
    public static func predicate(format: String, _ args: CVarArg...) -> NSPredicate {
        let p = withVaList(args) { NSPredicate(format: format, arguments: $0) }
        return predicate(p)
    }
    /// Creates a merged pedicate with the default predicate of the entity
    public static func predicate(_ predicate: NSPredicate) -> NSPredicate {
        NSCompoundPredicate(type: .and, subpredicates: [defaultPredicate, predicate])
    }
}

extension Managed where Self: NSManagedObject {
    public static var entity: NSEntityDescription { entity() }
    public static var entityName: String { entity.name!  }
    
    public static func findOrCreate(in context: NSManagedObjectContext, matching predicate: NSPredicate, configure: (Self) -> ()) -> Self {
        guard let object = findOrFetch(in: context, matching: predicate) else {
            let newObject: Self = context.insertObject()
            configure(newObject)
            return newObject
        }
        return object
    }
    
    /// Try to find an object in memory first and only fetch if it can't be found
    public static func findOrFetch(in context: NSManagedObjectContext, matching predicate: NSPredicate, includingSubentities: Bool? = nil) -> Self? {
        let actuallyIncludingSubentities = includingSubentities ?? self.defaultIncludesSubentities
        return materializedObject(in: context, matching: predicate, includingSubentities: actuallyIncludingSubentities)
            ?? fetch(in: context) { request in
                   request.predicate = predicate
                   request.includesSubentities = actuallyIncludingSubentities
                   request.returnsObjectsAsFaults = false
                   request.fetchLimit = 1
               }.first
    }
    
    /// Fetch
    ///
    /// The fetch request to use can be configured with the given block
    public static func fetch(in context: NSManagedObjectContext, configurationBlock: (NSFetchRequest<Self>) -> () = { _ in }) -> [Self] {
        let request = NSFetchRequest<Self>(entityName: Self.entityName)
        request.includesSubentities = Self.defaultIncludesSubentities
        configurationBlock(request)
        return try! context.fetch(request)
    }
    
    /// Count the number of entities
    ///
    /// The fetch request to use can be configured with the given block
    public static func count(in context: NSManagedObjectContext, configure: (NSFetchRequest<Self>) -> () = { _ in }) -> Int {
        let request = NSFetchRequest<Self>(entityName: entityName)
        configure(request)
        return try! context.count(for: request)
    }
    
    /// Return matching enitties only if they are already in memory
    public static func materializedObject(in context: NSManagedObjectContext, matching predicate: NSPredicate, includingSubentities: Bool = false) -> Self? {
        return context.registeredObjects.first {
            // We do not want to get a fault and by that trigger a database fetch
            !$0.isFault &&
            // Check if subclasses should be evaluated
            (includingSubentities || type(of: $0) == Self.self) &&
            predicate.evaluate(with: $0)
        } as? Self
    }
}

// MARK: - Single Object Cache

extension Managed where Self: NSManagedObject {
    public static func fetchSingleObject(in context: NSManagedObjectContext, cacheKey: String, configure: (NSFetchRequest<Self>) -> ()) -> Self? {
        if let cached = context.object(forSingleObjectCacheKey: cacheKey) as? Self { return cached
        }
        let result = fetchSingleObject(in: context, configure: configure)
        context.set(result, forSingleObjectCacheKey: cacheKey)
        return result
    }
    
    private static func fetchSingleObject(in context: NSManagedObjectContext, configure: (NSFetchRequest<Self>) -> ()) -> Self? {
        let result = fetch(in: context) { request in
            configure(request)
            request.fetchLimit = 2
        }
        switch result.count {
        case 0: return nil
        case 1: return result[0]
        default: fatalError("Returned multiple objects, expected max 1")
        }
    }
}
