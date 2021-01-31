import XCTest
import CoreData
@testable import CoreDataSupport

final class ExtendedFetchedResultsControllerTests: CoreDataTestCase {
    var observers: [Any] = []

    var milkyway: MOGalaxy!
    var sun: MOStar!
    var sirius: MOStar!
    var arcturus: MOStar!
    var earth: MOPlanet!
    var moon: MOMoon!
    var mars: MOPlanet!
    var phobos: MOMoon!
    var deimos: MOMoon!

    override func setUpWithError() throws {
        try super.setUpWithError()
        
        milkyway = MOGalaxy(context: container.viewContext)
        milkyway.id = UUID()
        milkyway.name = "Milky Way"
        
        sun = star("Sun", in: milkyway, container: container)
        sirius = star("Sirius", in: milkyway, container: container)
        arcturus = star("Arcturus", in: milkyway, container: container)
        earth = planet("Earth", around: sun, container: container)
        moon = moon("Moon", around: earth, container: container)
        mars = planet("Mars", around: sun, container: container)
        phobos = moon("Phobos", around: mars, container: container)
        deimos = moon("Deimos", around: mars, container: container)
        
        try container.viewContext.save()
    }
    
    override func tearDown() {
        observers = []
        super.tearDown()
    }
    
    func testRelationshipPropertyChange() throws {
        let baseFetchRequest = MOGalaxy.fetchRequest() as! NSFetchRequest<MOGalaxy>
        baseFetchRequest.sortDescriptors = [.init(key: #keyPath(MOGalaxy.name), ascending: true)]
        
        let fetchRequest = ExtendedFetchRequest(
            request: baseFetchRequest,
            relationshipKeyPaths: [#keyPath(MOGalaxy.stars.name)])
        
        let frc = ExtendedFetchedResultsController<MOGalaxy>(
            managedObjectContext: container.viewContext,
            fetchRequest: fetchRequest)

        observers.append(expectUpdate(in: frc) { object, _, _ in
            XCTAssertEqual(object, self.milkyway, "Expecting galaxy to receive update")
            XCTAssertTrue(object.changedValues().isEmpty, "Expecting update but no changes on Galaxy")
        })

        try frc.performFetch()
        
        // We expect the galaxy frc to catch this 💪
        sun.name = "Sonne"
        
        try container.viewContext.save()
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func testRelationshipOrderChange() throws {
        let baseFetchRequest = MOMoon.fetchRequest() as! NSFetchRequest<MOMoon>
        baseFetchRequest.sortDescriptors = [
            .init(key: #keyPath(MOMoon.planet.name), ascending: true),
            .init(key: #keyPath(MOMoon.name), ascending: true),
        ]
        
        let fetchRequest = ExtendedFetchRequest(
            request: baseFetchRequest,
            relationshipKeyPaths: [#keyPath(MOMoon.planet.name)])
        
        let frc = ExtendedFetchedResultsController<MOMoon>(
            managedObjectContext: container.viewContext,
            fetchRequest: fetchRequest)

        // Until the observer is fixed to allow for multiple instanes for the same frc
        // this is not possible. The last observation always unhooks the delegate of the previous
        
        // observers.append(expectUpdate(in: frc) { object, atIndex, progressiveChangeIndex  in
        //     XCTAssertEqual(object, self.moon, "Expecting moon to receive update")
        //     XCTAssertEqual(frc.fetchedObjects.map(\.name), [self.deimos.name, self.phobos.name, self.moon.name])
        // })
        
        observers.append(expectMove(in: frc) { object, fromIndex, toIndex, progressiveChangeIndex in
            XCTAssertEqual(object, self.moon, "Expecting moon to receive move")
            XCTAssertEqual(fromIndex.item, 0)
            XCTAssertEqual(toIndex.item, 2)
        })

        try frc.performFetch()
        // Result is ordered by planet's name first, then the moon's name
        // Moon, Deimos, Phobos
        
        // This should change the order to
        // Deimos, Phobos, Moon
        earth.name = "Z"
        
        try container.viewContext.save()
        
        waitForExpectations(timeout: 3, handler: nil)
    }
}

extension XCTestCase {
    func star(_ name: String, in galaxy: MOGalaxy, container: NSPersistentContainer) -> MOStar {
        let s = MOStar(context: container.viewContext)
        s.id = UUID()
        s.name = name
        s.galaxy = galaxy
        return s
    }
    func planet(_ name: String, around star: MOStar, container: NSPersistentContainer) -> MOPlanet {
        let p = MOPlanet(context: container.viewContext)
        p.id = UUID()
        p.name = name
        p.star = star
        return p
    }
    func moon(_ name: String, around planet: MOPlanet, container: NSPersistentContainer) -> MOMoon {
        let m = MOMoon(context: container.viewContext)
        m.id = UUID()
        m.name = name
        m.craters = Int.random(in: 0..<100)
        m.comets = Int.random(in: 0..<5)
        m.planet = planet
        return m
    }
    
    func expectUpdate<EntityType>(in frc: ExtendedFetchedResultsController<EntityType>, _ expect: @escaping (EntityType, IndexPath, IndexPath) -> Void) -> ExtendedFetchedResultsControllerObserver<EntityType> where EntityType: NSFetchRequestResult {
        let e = expectation(description: "update-\(UUID().uuidString)")
        return ExtendedFetchedResultsControllerObserver(frc) { event in
            print(event)
            if case let .updateWithChange(change) = event, case let .update(object: object, at: atIndex, progressiveChangeIndexPath: progressiveChangeIndexPath) = change {
                expect(object, atIndex, progressiveChangeIndexPath)
                e.fulfill()
            }
        }
    }
    
    func expectMove<EntityType>(in frc: ExtendedFetchedResultsController<EntityType>, _ expect: @escaping (EntityType, IndexPath, IndexPath, IndexPath) -> Void) -> ExtendedFetchedResultsControllerObserver<EntityType> where EntityType: NSFetchRequestResult {
        let e = expectation(description: "move-\(UUID().uuidString)")
        return ExtendedFetchedResultsControllerObserver(frc) { event in
            print(event)
            if case let .updateWithChange(change) = event, case let .move(object: object, from: fromIndex, to: toIndex, progressiveChangeIndexPath: progressiveChangeIndexPath) = change {
                expect(object, fromIndex, toIndex, progressiveChangeIndexPath)
                e.fulfill()
            }
        }
    }
}
