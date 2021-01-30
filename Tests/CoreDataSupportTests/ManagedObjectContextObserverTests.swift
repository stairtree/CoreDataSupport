import XCTest
import CoreData
@testable import CoreDataSupport

final class ManagedObjectContextObserverTests: CoreDataTestCase {
    var observers: [ManagedObjectContextObserver] = []
    
    override func tearDown() {
        observers = []
        super.tearDown()
    }
    func testNotifications() throws {
        let galaxy = MOGalaxy(context: container.viewContext)
        galaxy.id = UUID()
        galaxy.name = "The Galaxy"
        
        observers.append(expectDidChange(in: container.viewContext, { note in
            XCTAssertEqual(note.insertedObjects.count, 1)
            XCTAssert(note.insertedObjects.contains(where: { $0.entity.name == "MOGalaxy" }))
        }))
        
        observers.append(expectWillSave(in: container.viewContext, { note in
            XCTAssertTrue(note.managedObjectContext.insertedObjects.contains(galaxy))
        }))
        
        observers.append(expectDidSave(in: container.viewContext, { note in
            XCTAssertTrue(note.insertedObjects.contains(galaxy))
        }))
        
        observers.append(expectDidSaveObjectIDs(in: container.viewContext, { note in
            XCTAssertFalse(note.insertedObjectIDs.isEmpty)
        }))
        
        try container.viewContext.save()
        
        waitForExpectations(timeout: 3, handler: nil)
        // Discard previous expectations
        observers = []
                
        observers.append(expectDidChange(in: container.viewContext) { note in
            XCTAssertTrue(note.updatedObjects.contains(galaxy))
            XCTAssertNotNil(galaxy.changedValue(forKey: "appendix"))
        })
        
        galaxy.appendix = .init("An appendix to The Galaxy. Why not?")
        
        waitForExpectations(timeout: 3, handler: nil)
    }
}

extension XCTestCase {
    func expectDidChange(in context: NSManagedObjectContext, _ expect: @escaping (ObjectsDidChangeNotification) -> Void) -> ManagedObjectContextObserver {
        let e = expectation(description: "didChange-\(UUID().uuidString)")
        return ManagedObjectContextObserver(moc: context) { change in
            if case let .didChange(note) = change {
                expect(note)
                e.fulfill()
            }
        }
    }
    func expectWillSave(in context: NSManagedObjectContext, _ expect: @escaping (ContextWillSaveNotification) -> Void) -> ManagedObjectContextObserver {
        let e = expectation(description: "willSave-\(UUID().uuidString)")
        return ManagedObjectContextObserver(moc: context) { change in
            if case let .willSave(note) = change {
                expect(note)
                e.fulfill()
            }
        }
    }
    func expectDidSave(in context: NSManagedObjectContext, _ expect: @escaping (ContextDidSaveNotification) -> Void) -> ManagedObjectContextObserver {
        let e = expectation(description: "didSave-\(UUID().uuidString)")
        return ManagedObjectContextObserver(moc: context) { change in
            if case let .didSave(note) = change {
                expect(note)
                e.fulfill()
            }
        }
    }
    func expectDidSaveObjectIDs(in context: NSManagedObjectContext, _ expect: @escaping (ContextDidSaveObjectIDsNotification) -> Void) -> ManagedObjectContextObserver {
        let e = expectation(description: "didSaveObjectIDs-\(UUID().uuidString)")
        return ManagedObjectContextObserver(moc: context) { change in
            if case let .didSaveObjectIDs(note) = change {
                expect(note)
                e.fulfill()
            }
        }
    }
}
