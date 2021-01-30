import XCTest
import CoreDataSupport

class CoreDataTestCase: XCTestCase {
    var container: NSPersistentContainer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        
        container = ModelCachingPersistentContainer(name: "CoreDataTestCase", managedObjectModel: SolarSystemManagedObjectModel())
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]

        let descriptions = try XCTUnwrap(container.loadPersistentStores())
        
        XCTAssertEqual(descriptions.first?.type, NSInMemoryStoreType)
    }

    override func tearDown() {
        container = nil
        super.tearDown()
    }
}
