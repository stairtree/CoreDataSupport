import XCTest
import CoreData
@testable import CoreDataSupport

final class ExtendedFetchedResultsControllerTests: XCTestCase {
    var observer: Any?
    
    override func tearDown() {
        observer = nil
        super.tearDown()
    }
    
    func testRelationshipChange() throws {
        let container = try XCTUnwrap(TestPersistentContainer.testable(in: self, for: SolarSystemManagedObjectModel()))
        
        let milkyway = MOGalaxy(context: container.viewContext)
        milkyway.id = UUID()
        milkyway.name = "The Galaxy"
        
        let sun = MOStar(context: container.viewContext)
        sun.id = UUID()
        sun.name = "Sun"
        sun.galaxy = milkyway

        try container.viewContext.save()
        
        let baseFetchRequest = MOGalaxy.fetchRequest() as! NSFetchRequest<MOGalaxy>
        baseFetchRequest.sortDescriptors = [.init(key: #keyPath(MOGalaxy.name), ascending: true)]
        
        let fetchRequest = ExtendedFetchRequest(
            request: baseFetchRequest,
            relationshipKeyPaths: [#keyPath(MOGalaxy.stars.name)])
        
        let frc = ExtendedFetchedResultsController<MOGalaxy>(
            managedObjectContext: container.viewContext,
            fetchRequest: fetchRequest)

        observer = expectUpdate(in: frc) { object in
            XCTAssertEqual(object, milkyway, "Expecting galaxy to receive update")
        }

        try frc.performFetch()
        
        // We expect the galaxy frc to catch this 💪
        sun.name = "Sonne"
        
        try container.viewContext.save()
        waitForExpectations(timeout: 3, handler: nil)
    }
}

final class ExtendedFetchedResultsControllerObserver<EntityType: NSFetchRequestResult>: NSObject, FetchedResultsControllerDelegate {
    private weak var fetchedResultsController: ExtendedFetchedResultsController<EntityType>!
    private let handler: (Event) -> Void
    
    public enum Event {
        case willChangeContent
        case updateWithChange(_ change: WrappedNSFetchedResultsController<EntityType>.ChangeType)
        case didChangeContent
    }
    
    public init(_ frc: ExtendedFetchedResultsController<EntityType>, handler: @escaping (Event) -> Void) {
        self.fetchedResultsController = frc
        self.handler = handler
        super.init()
        frc.delegate = self
    }
    
    func willChangeContent<T>(_ controller: WrappedNSFetchedResultsController<T>) where T: NSFetchRequestResult {
        handler(.willChangeContent)
    }
    
    func updateWithChange<T>(_ controller: WrappedNSFetchedResultsController<T>, change: WrappedNSFetchedResultsController<T>.ChangeType) where T: NSFetchRequestResult {
        handler(.updateWithChange(change as! WrappedNSFetchedResultsController<EntityType>.ChangeType))
    }
    
    func didChangeContent<T>(_ controller: WrappedNSFetchedResultsController<T>) where T: NSFetchRequestResult {
        handler(.didChangeContent)
    }
}

extension XCTestCase {

    func expectUpdate<EntityType>(in frc: ExtendedFetchedResultsController<EntityType>, _ expect: @escaping (EntityType) -> Void) -> ExtendedFetchedResultsControllerObserver<EntityType> where EntityType: NSFetchRequestResult {
        let e = expectation(description: "update")
        return ExtendedFetchedResultsControllerObserver(frc) { event in
            if case let .updateWithChange(change) = event, case let .update(object: object, atIndex: _, progressiveChangeIndex: _) = change {
                expect(object)
                e.fulfill()
            }
        }
    }
}
