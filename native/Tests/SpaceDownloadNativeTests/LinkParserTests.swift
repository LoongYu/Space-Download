import Foundation
import XCTest
@testable import SpaceDownloadNative

final class LinkParserTests: XCTestCase {
    func testParsesMultipleLinksAndRemovesDuplicates() {
        let result = LinkParser.parse("""
        https://example.com/video/1
        https://example.com/video/2
        https://example.com/video/1
        """)

        XCTAssertEqual(result.validURLs.map(\.absoluteString), [
            "https://example.com/video/1",
            "https://example.com/video/2",
        ])
        XCTAssertTrue(result.invalidEntries.isEmpty)
    }

    func testReportsInvalidEntries() {
        let result = LinkParser.parse("not-a-url\nftp://example.com/file")

        XCTAssertTrue(result.validURLs.isEmpty)
        XCTAssertEqual(result.invalidEntries, ["not-a-url", "ftp://example.com/file"])
    }
}
