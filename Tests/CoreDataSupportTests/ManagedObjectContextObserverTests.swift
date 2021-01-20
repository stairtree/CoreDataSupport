import XCTest
import CoreData
@testable import CoreDataSupport

final class ManagedObjectContextObserverTests: XCTestCase {
    var observer: ManagedObjectContextObserver?
    
    override func tearDown() {
        observer = nil
        super.tearDown()
    }
    func testNotifications() throws {
        let container = try XCTUnwrap(TestPersistentContainer.testable(in: self, for: SolarSystemManagedObjectModel()))
        
        let didChangeExpectation = expectation(description: "didChange")
        let willSaveExpectation = expectation(description: "willSave")
        let didSaveExpectation = expectation(description: "didSave")
        let didSaveObjectIDsExpectation = expectation(description: "didSaveObjectIDs")

        observer = ManagedObjectContextObserver(moc: container.viewContext) { change in
            switch change {
            case .didChange(let note):
                XCTAssertEqual(note.insertedObjects.count, 1)
                XCTAssert(note.insertedObjects.contains(where: { $0.entity.name == "MOGalaxy" }))
                didChangeExpectation.fulfill()
            case .willSave(_):
                willSaveExpectation.fulfill()
            case .didSave(_):
                didSaveExpectation.fulfill()
            case .didSaveObjectIDs(_):
                didSaveObjectIDsExpectation.fulfill()
            }
        }
        
        let galaxy = MOGalaxy(context: container.viewContext)
        galaxy.id = UUID()
        galaxy.name = "The Galaxy"
        
        try container.viewContext.save()
        
        waitForExpectations(timeout: 3, handler: nil)
                
        observer = expectDidChange(in: container.viewContext) { note in
            XCTAssertTrue(note.updatedObjects.contains(galaxy))
            XCTAssertNotNil(galaxy.changedValue(forKey: "appendix"))
        }
        
        galaxy.appendix = .init("An appendix to The Galaxy. Why not?")
        
        waitForExpectations(timeout: 3, handler: nil)
    }
}

extension XCTestCase {

    func expectDidChange(in context: NSManagedObjectContext, _ expect: @escaping (ObjectsDidChangeNotification) -> Void) -> ManagedObjectContextObserver {
        let e = expectation(description: "didChange")
        return ManagedObjectContextObserver(moc: context) { change in
            if case let .didChange(note) = change {
                expect(note)
                e.fulfill()
            }
        }
    }
}
