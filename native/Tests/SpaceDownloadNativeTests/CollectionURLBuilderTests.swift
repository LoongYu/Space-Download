import Foundation
import XCTest
@testable import SpaceDownloadNative

final class CollectionURLBuilderTests: XCTestCase {
    func testBuildsPornhubProfilePageURL() throws {
        let source = try XCTUnwrap(URL(string: "https://www.pornhub.com/model/example?o=mr"))
        let result = try XCTUnwrap(CollectionURLBuilder.pageURL(from: source, page: 3))

        XCTAssertEqual(result.path, "/model/example/videos")
        let components = try XCTUnwrap(URLComponents(url: result, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "page" })?.value, "3")
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "o" })?.value, "mr")
    }

    func testPlaylistDoesNotSupportPageSelection() throws {
        let url = try XCTUnwrap(URL(string: "https://www.pornhub.com/playlist/123"))
        XCTAssertTrue(CollectionURLBuilder.isCollection(url))
        XCTAssertFalse(CollectionURLBuilder.supportsPageSelection(url))
    }
}
