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
            }
        }
        
        let galaxy = MOGalaxy(context: container.viewContext)
        galaxy.id = UUID()
        galaxy.name = "The Galaxy"
        
        try container.viewContext.save()
        
        wait(for: [didChangeExpectation, willSaveExpectation, didSaveExpectation], timeout: 3)
        
        let didChangeExpectation2 = expectation(description: "didChange2")
        
        observer = ManagedObjectContextObserver(moc: container.viewContext) { change in
            switch change {
            case .didChange(let note):
                XCTAssertTrue(note.updatedObjects.contains(galaxy))
                XCTAssertNotNil(galaxy.changedValue(forKey: "appendix"))
                didChangeExpectation2.fulfill()
            case .willSave(_):
                XCTFail()
            case .didSave(_):
                XCTFail()
            }
        }
        
        galaxy.appendix = .init("An appendix to The Galaxy. Why not?")
        
        wait(for: [didChangeExpectation2], timeout: 3)
    }
}
