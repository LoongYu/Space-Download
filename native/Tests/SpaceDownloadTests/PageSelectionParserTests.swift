import XCTest
@testable import SpaceDownload

final class PageSelectionParserTests: XCTestCase {
    func testParsesRangesAndIndividualPages() throws {
        XCTAssertEqual(try PageSelectionParser.parse("1-3, 5, 3"), [1, 2, 3, 5])
    }

    func testEmptySelectionMeansAllPages() throws {
        XCTAssertNil(try PageSelectionParser.parse("  "))
    }

    func testRejectsInvalidRange() {
        XCTAssertThrowsError(try PageSelectionParser.parse("3-1")) { error in
            XCTAssertEqual(error as? PageSelectionError, .invalidToken("3-1"))
        }
    }

    func testRejectsNonPositivePage() {
        XCTAssertThrowsError(try PageSelectionParser.parse("0"))
    }
}
