import XCTest
import CoreData
import CoreDataSupport

class CoreDataTestCase: XCTestCase {
    var container: NSPersistentContainer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        
        container = ModelCachingPersistentContainer(name: "CoreDataTestCase", managedObjectModel: SolarSystemManagedObjectModel())
        let description = NSPersistentStoreDescription()
        description.url = URL(fileURLWithPath: "/dev/null")
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]

        let descriptions = try XCTUnwrap(container.loadPersistentStores())
        
        XCTAssertEqual(descriptions.first?.type, NSSQLiteStoreType)
    }

    override func tearDown() {
        container = nil
        super.tearDown()
    }
}
