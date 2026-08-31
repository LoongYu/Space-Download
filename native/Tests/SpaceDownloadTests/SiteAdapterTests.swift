import Foundation
import XCTest
@testable import SpaceDownload

final class SiteAdapterTests: XCTestCase {
    func testYouTubeClassifiesSupportedLinkTypes() throws {
        let adapter = YouTubeAdapter()

        XCTAssertEqual(
            adapter.classify(try XCTUnwrap(URL(string: "https://youtu.be/dQw4w9WgXcQ"))),
            .singleVideo
        )
        XCTAssertEqual(
            adapter.classify(try XCTUnwrap(URL(string: "https://www.youtube.com/watch?v=abc&list=PL123"))),
            .singleVideo
        )
        XCTAssertEqual(
            adapter.classify(try XCTUnwrap(URL(string: "https://www.youtube.com/playlist?list=PL123"))),
            .playlist
        )
        XCTAssertEqual(
            adapter.classify(try XCTUnwrap(URL(string: "https://www.youtube.com/@creator"))),
            .channel
        )
    }

    func testYouTubeChannelScopeBuildsDedicatedTabURL() throws {
        var settings = DownloadSettings.defaults
        settings.sites.youtube.channelScope = .shorts
        let request = DownloadRequest(
            sourceURLs: [],
            settings: settings,
            credentials: .init(),
            selectedPages: nil
        )
        let source = try XCTUnwrap(URL(string: "https://www.youtube.com/@creator/videos"))

        let result = try XCTUnwrap(YouTubeAdapter().collectionSources(for: source, request: request).first)

        XCTAssertEqual(result.url.absoluteString, "https://www.youtube.com/@creator/shorts")
        XCTAssertEqual(result.label, "YouTube 频道")
    }

    func testYouTubePlaylistSelectionAndFlatEntryURL() throws {
        let request = DownloadRequest(
            sourceURLs: [],
            settings: .defaults,
            credentials: .init(),
            selectedPages: nil,
            youtubePlaylistItems: [1, 2, 5]
        )
        let adapter = YouTubeAdapter()
        let playlist = try XCTUnwrap(URL(string: "https://www.youtube.com/playlist?list=PL123"))
        let channel = try XCTUnwrap(URL(string: "https://www.youtube.com/@creator"))

        XCTAssertEqual(
            adapter.collectionArguments(for: playlist, request: request),
            ["--playlist-items", "1,2,5"]
        )
        XCTAssertTrue(adapter.collectionArguments(for: channel, request: request).isEmpty)
        XCTAssertEqual(
            adapter.resolvedEntryURL(from: ["id": "dQw4w9WgXcQ"])?.absoluteString,
            "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        )
    }

    func testRegistryKeepsPornhubAndYouTubeSeparate() throws {
        let pornhub = try XCTUnwrap(URL(string: "https://www.pornhub.com/model/example"))
        let youtube = try XCTUnwrap(URL(string: "https://www.youtube.com/@creator"))

        XCTAssertEqual(SiteRegistry.adapter(for: pornhub).siteID, .pornhub)
        XCTAssertEqual(SiteRegistry.adapter(for: youtube).siteID, .youtube)
        XCTAssertEqual(SiteRegistry.detectedSites(in: [pornhub, youtube]), [.pornhub, .youtube])
    }

    func testYouTubeJavaScriptRuntimeLocatorFindsNodeInConfiguredDirectory() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let node = directory.appendingPathComponent("node")
        try Data("#!/bin/sh\n".utf8).write(to: node)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: node.path)

        let runtime = try XCTUnwrap(YouTubeJavaScriptRuntimeLocator.locate(
            environment: [:],
            systemDirectories: [directory]
        ))

        XCTAssertEqual(runtime.name, "node")
        XCTAssertEqual(runtime.url, node)
        XCTAssertEqual(runtime.argument, "node:\(node.path)")
    }
}
