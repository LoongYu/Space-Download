import Foundation
import XCTest
@testable import SpaceDownload

final class LinkParserTests: XCTestCase {
    func testParsesTelegramPublicMessageShareURLs() {
        let result = LinkParser.parse("https://telegram.me/europa_press/613?single\nhttps://t.me/TelegramTips/518")
        XCTAssertTrue(result.invalidEntries.isEmpty)
        XCTAssertEqual(result.validURLs.map(\.absoluteString), [
            "https://telegram.me/europa_press/613?single",
            "https://t.me/TelegramTips/518",
        ])
    }

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
