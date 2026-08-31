import Foundation
import XCTest
@testable import SpaceDownload

final class ExistingVideoLocatorTests: XCTestCase {
    func testExtractsPornhubViewKey() throws {
        let url = try XCTUnwrap(URL(string: "https://cn.pornhub.com/view_video.php?viewkey=68569e24d762e"))
        XCTAssertEqual(ExistingVideoLocator.videoID(from: url), "68569e24d762e")
    }

    func testFindsExistingVideoRecursivelyButIgnoresThumbnail() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let nested = directory.appendingPathComponent("author", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let thumbnail = nested.appendingPathComponent("title(abc123).jpg")
        let video = nested.appendingPathComponent("title(abc123).mp4")
        try Data().write(to: thumbnail)
        XCTAssertNil(ExistingVideoLocator.find(videoID: "abc123", in: directory))
        try Data().write(to: video)
        let found = try XCTUnwrap(ExistingVideoLocator.find(videoID: "abc123", in: directory))
        XCTAssertEqual(found.resolvingSymlinksInPath(), video.resolvingSymlinksInPath())
    }
}
