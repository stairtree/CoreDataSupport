import XCTest
@testable import CoreDataSupport

final class CoreDataSupportTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(CoreDataSupport().text, "Hello, World!")
    }


    static var allTests = [
        ("testExample", testExample),
    ]
}
