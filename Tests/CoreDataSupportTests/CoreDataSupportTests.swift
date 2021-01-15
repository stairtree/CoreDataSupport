import XCTest
import CoreData
@testable import CoreDataSupport

final class GalaxyAppendix: NSObject, Codable {
    let content: String
    
    init(_ content: String) {
        self.content = content
    }
}

class MOAstronomicalObject: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
}

final class MOGalaxy: MOAstronomicalObject {
    @NSManaged public var stars: [MOStar]
    @NSManaged public var appendix: GalaxyAppendix
}

final class MOStar: MOAstronomicalObject {
    @NSManaged public var galaxy: MOGalaxy
    @NSManaged public var planets: [MOPlanet]
}

final class MOPlanet: MOAstronomicalObject {
    @NSManaged public var star: MOStar
    @NSManaged public var moons: [MOMoon]
    @NSManaged public var tags: [MOTag]
}

final class MOMoon: MOAstronomicalObject {
    @NSManaged public var craters: Int
    @NSManaged public var comets: Int
    @NSManaged public var planet: MOPlanet
}

final class MOTag: MOAstronomicalObject {
    @NSManaged public var planets: [MOPlanet]
}

internal func SolarSystemManagedObjectModel() -> NSManagedObjectModel {

    return NSManagedObjectModel {
        
        // MOAstronomicalObject
        $0.abstractEntity(for: MOAstronomicalObject.self, name: "MOAstronomicalObject") { $0
            .attribute("id", UUID.self, .required)
            .attribute("name", String.self, .required)
        }
        
        // MOGalaxy
        $0.entity(for: MOGalaxy.self, name: "MOGalaxy") {
            $0.attribute("appendix", GalaxyAppendix.self)
        }
        
        // MOStar
        $0.entity(for: MOStar.self, name: "MOStar") { _ in }
        
        // MOPlanet
        $0.entity(for: MOPlanet.self, name: "MOPlanet") { _ in }
        
        // MOMoon
        $0.entity(for: MOMoon.self, name: "MOMoon") { $0
            .attribute("craters", Int.self, .required)
            .attribute("comets", Int.self, .required)
        }
        
        // MOTag
        $0.entity(for: MOTag.self) { _ in }
        
        // MOGalaxy -> [MOStar]
        $0.relate(MOGalaxy.self, "stars", toMany: MOStar.self, "galaxy")
        
        // MOStar -> [MOPlanet]
        $0.relate(MOStar.self, "planets", toMany: MOPlanet.self, "star")
        
        // MOPlanet -> [MOMoon]
        $0.relate(MOPlanet.self, "moons", toManyOrdered: MOMoon.self, "planet")
        
        // [MOPlanet] <-> [MOTag]
        $0.relate(many: MOTag.self, "planets", toMany: MOPlanet.self, "tags")
    }
}

extension XCTestCase {

    var swiftifiedName: String {
        
        return self.name
            .replacingOccurrences(of: "-[", with: "")
            .replacingOccurrences(of: " ", with: ".")
            .replacingOccurrences(of: "]", with: "")
        
    }
}

final class TestPersistentContainer: NSPersistentContainer {

    static var perInstanceURLWorkaroundLock = NSLock()
    static var perInstanceURLWorkaroundCurrent: URL?

    override class func defaultDirectoryURL() -> URL {
        // precondition(perInstanceURLWorkaroundLock.try() == false, "Lock must be held when this method is called.")
        let url = perInstanceURLWorkaroundCurrent ?? super.defaultDirectoryURL()
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        return url
    }
    
    required init(name: String, defaultURL: URL, model: NSManagedObjectModel) {
        Self.perInstanceURLWorkaroundLock.lock()
        defer { Self.perInstanceURLWorkaroundLock.unlock() }
        Self.perInstanceURLWorkaroundCurrent = defaultURL
        super.init(name: name, managedObjectModel: model)
    }

    static func testable(in testcase: XCTestCase, for model: NSManagedObjectModel) throws -> TestPersistentContainer {
        let container = self.init(name: testcase.swiftifiedName, defaultURL: URL(fileURLWithPath: "/tmp", isDirectory: true), model: model)
        let loadExpectation = XCTestExpectation(description: "Persistent store loading completed")
        var loadError: Error?
        
        container.loadPersistentStores(completionHandler: { store, error in
            if let error = error {
                loadError = error
            }
            loadExpectation.fulfill()
        })
        XCTWaiter().wait(for: [loadExpectation], timeout: .infinity)
        if let error = loadError {
            throw error
        }
        return container
    }
}

final class CoreDataSupportTests: XCTestCase {

    func testModelBuilder() throws {
        
        let container = try XCTUnwrap(TestPersistentContainer.testable(in: self, for: SolarSystemManagedObjectModel()))
        let galaxy = MOGalaxy(context: container.viewContext)

        galaxy.id = UUID()
        galaxy.name = "The Galaxy"
        galaxy.appendix = .init("An appendix to The Galaxy. Why not?")
        XCTAssertNoThrow(try container.viewContext.save())
        
    }
}
