import CoreData

public protocol Managed: AnyObject, NSFetchRequestResult {
    static var entity: NSEntityDescription { get }
    static var entityName: String { get }
    static var defaultSortDescriptors: [NSSortDescriptor] { get }
    static var defaultPredicate: NSPredicate { get }
    static var defaultIncludesSubentities: Bool { get }
    static var defaultRelationshipKeyPathsForPrefetching: [String] { get }
    var managedObjectContext: NSManagedObjectContext? { get }
}

extension Managed {
    public static var defaultSortDescriptors: [NSSortDescriptor] { [] }
    public static var defaultPredicate: NSPredicate { NSPredicate(value: true) }
    public static var defaultRelationshipKeyPathsForPrefetching: [String] { [] }
    
    public static var sortedFetchRequest: NSFetchRequest<Self> {
        let request = NSFetchRequest<Self>(entityName: entityName)
        request.sortDescriptors = defaultSortDescriptors
        request.predicate = defaultPredicate
        request.includesSubentities = defaultIncludesSubentities
        request.relationshipKeyPathsForPrefetching = defaultRelationshipKeyPathsForPrefetching
        return request
    }
    
    public static func sortedFetchRequest(with predicate: NSPredicate) -> NSFetchRequest<Self> {
        let request = sortedFetchRequest
        guard let existingPredicate = request.predicate else { fatalError("must have predicate") }
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [existingPredicate, predicate])
        return request
    }
    
    public static func predicate(format: String, _ args: CVarArg...) -> NSPredicate {
        let p = withVaList(args) { NSPredicate(format: format, arguments: $0) }
        return predicate(p)
    }
    
    public static func predicate(_ predicate: NSPredicate) -> NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: [defaultPredicate, predicate])
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
    
    public static func findOrFetch(in context: NSManagedObjectContext, matching predicate: NSPredicate, includingSubentities: Bool? = nil) -> Self? {
        let actuallyIncludingSubentities = includingSubentities ?? self.defaultIncludesSubentities
        return materializedObject(in: context, matching: predicate, includingSubentities: actuallyIncludingSubentities) ??
               fetch(in: context) { request in
                   request.predicate = predicate
                   request.includesSubentities = actuallyIncludingSubentities
                   request.returnsObjectsAsFaults = false
                   request.fetchLimit = 1
               }.first
    }
    
    public static func fetch(in context: NSManagedObjectContext, configurationBlock: (NSFetchRequest<Self>) -> () = { _ in }) -> [Self] {
        let request = NSFetchRequest<Self>(entityName: Self.entityName)
        request.includesSubentities = Self.defaultIncludesSubentities
        configurationBlock(request)
        return try! context.fetch(request)
    }
    
    public static func count(in context: NSManagedObjectContext, configure: (NSFetchRequest<Self>) -> () = { _ in }) -> Int {
        let request = NSFetchRequest<Self>(entityName: entityName)
        configure(request)
        return try! context.count(for: request)
    }
    
    public static func materializedObject(in context: NSManagedObjectContext, matching predicate: NSPredicate, includingSubentities: Bool = false) -> Self? {
        return context.registeredObjects.first {
            !$0.isFault &&
            (includingSubentities || type(of: $0) == Self.self) &&
            predicate.evaluate(with: $0)
        } as? Self
    }

    public static func fetchSingleObject(in context: NSManagedObjectContext, cacheKey: String, configure: (NSFetchRequest<Self>) -> ()) -> Self? {
        if let cached = context.object(forSingleObjectCacheKey: cacheKey) as? Self { return cached
        }
        let result = fetchSingleObject(in: context, configure: configure)
        context.set(result, forSingleObjectCacheKey: cacheKey)
        return result
    }
    
    fileprivate static func fetchSingleObject(in context: NSManagedObjectContext, configure: (NSFetchRequest<Self>) -> ()) -> Self? {
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
