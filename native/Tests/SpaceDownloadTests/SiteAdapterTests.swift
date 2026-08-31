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

    func testYouTubeSelectsHighestResolutionThumbnailAndMergesHeaders() throws {
        let metadata: [String: Any] = [
            "thumbnail": "https://i.ytimg.com/default.jpg",
            "http_headers": ["Referer": "https://www.youtube.com/", "User-Agent": "metadata-agent"],
            "thumbnails": [
                ["url": "https://i.ytimg.com/120.jpg", "width": 120, "height": 90],
                [
                    "url": "https://i.ytimg.com/1920.jpg",
                    "width": 1920,
                    "height": 1080,
                    "http_headers": ["User-Agent": "thumbnail-agent"],
                ],
                ["url": "https://i.ytimg.com/1280.jpg", "width": 1280, "height": 720],
            ],
        ]

        let thumbnail = try XCTUnwrap(YouTubeAdapter().preferredThumbnail(from: metadata))

        XCTAssertEqual(thumbnail.url.absoluteString, "https://i.ytimg.com/1920.jpg")
        XCTAssertEqual(thumbnail.width, 1920)
        XCTAssertEqual(thumbnail.height, 1080)
        XCTAssertEqual(thumbnail.headers["Referer"], "https://www.youtube.com/")
        XCTAssertEqual(thumbnail.headers["User-Agent"], "thumbnail-agent")
    }

    func testYouTubeThumbnailFallsBackToMetadataThumbnail() throws {
        let thumbnail = try XCTUnwrap(YouTubeAdapter().preferredThumbnail(from: [
            "thumbnail": "https://i.ytimg.com/fallback.jpg",
            "http_headers": ["Referer": "https://www.youtube.com/"],
        ]))

        XCTAssertEqual(thumbnail.url.absoluteString, "https://i.ytimg.com/fallback.jpg")
        XCTAssertNil(thumbnail.width)
        XCTAssertNil(thumbnail.height)
        XCTAssertEqual(thumbnail.headers["Referer"], "https://www.youtube.com/")
    }

    func testRegistryKeepsPornhubAndYouTubeSeparate() throws {
        let pornhub = try XCTUnwrap(URL(string: "https://www.pornhub.com/model/example"))
        let youtube = try XCTUnwrap(URL(string: "https://www.youtube.com/@creator"))

        XCTAssertEqual(SiteRegistry.adapter(for: pornhub).siteID, .pornhub)
        XCTAssertEqual(SiteRegistry.adapter(for: youtube).siteID, .youtube)
        XCTAssertEqual(SiteRegistry.detectedSites(in: [pornhub, youtube]), [.pornhub, .youtube])
    }

    func testXMatchesOnlyStatusLinksAndExpandsMultipleMediaKinds() throws {
        let adapter = XAdapter()
        let status = try XCTUnwrap(URL(string: "https://x.com/example/status/1234567890"))
        XCTAssertTrue(adapter.matches(status))
        XCTAssertTrue(adapter.matches(try XCTUnwrap(URL(string: "https://twitter.com/example/status/1234567890"))))
        XCTAssertFalse(adapter.matches(try XCTUnwrap(URL(string: "https://x.com/example"))))

        let resources = adapter.mediaResources(from: ["entries": [
            ["id": "1234567890-1", "title": "video", "ext": "mp4"],
            ["id": "1234567890-2", "title": "animation", "format": "animated gif"],
            ["id": "1234567890-3", "title": "photo", "ext": "jpg"],
        ]], sourceURL: status)

        XCTAssertEqual(resources.map(\.stableID), ["1234567890-1", "1234567890-2", "1234567890-3"])
        XCTAssertEqual(resources.map(\.kind), [.video, .animatedGIF, .image])
        XCTAssertEqual(resources.map(\.selector), [1, 2, 3])
        XCTAssertEqual(resources.map(\.isDownloadSupported), [true, true, false])
    }

    func testTikTokMatchesPublicVideoAndSafeShortLinksOnly() throws {
        let adapter = TikTokAdapter()
        XCTAssertTrue(adapter.matches(try XCTUnwrap(URL(string: "https://www.tiktok.com/@scout2015/video/6718335390845095173"))))
        XCTAssertTrue(adapter.matches(try XCTUnwrap(URL(string: "https://vm.tiktok.com/ZMexample/"))))
        XCTAssertTrue(adapter.matches(try XCTUnwrap(URL(string: "https://vt.tiktok.com/ZSexample/"))))
        XCTAssertFalse(adapter.matches(try XCTUnwrap(URL(string: "https://www.tiktok.com/@scout2015"))))
        XCTAssertFalse(adapter.matches(try XCTUnwrap(URL(string: "https://evil.example/@u/video/123"))))
        XCTAssertEqual(adapter.classify(try XCTUnwrap(URL(string: "https://vm.tiktok.com/ZMexample/"))), .singleVideo)
    }

    func testTikTokSelectsLargestMetadataThumbnailAndHeaders() throws {
        let thumbnail = try XCTUnwrap(TikTokAdapter().preferredThumbnail(from: [
            "http_headers": ["Referer": "https://www.tiktok.com/"],
            "thumbnails": [
                ["url": "https://example.com/small.jpeg", "width": 360, "height": 640],
                ["url": "https://example.com/large.jpeg", "width": 1080, "height": 1920,
                 "http_headers": ["User-Agent": "thumbnail-agent"]],
            ],
        ]))
        XCTAssertEqual(thumbnail.url.absoluteString, "https://example.com/large.jpeg")
        XCTAssertEqual(thumbnail.width, 1080)
        XCTAssertEqual(thumbnail.height, 1920)
        XCTAssertEqual(thumbnail.headers["Referer"], "https://www.tiktok.com/")
        XCTAssertEqual(thumbnail.headers["User-Agent"], "thumbnail-agent")
    }

    func testDouyinIsIndependentAndMatchesOnlyPublicVideoAndSafeShortLinks() throws {
        let adapter = DouyinAdapter()
        let standard = try XCTUnwrap(URL(string: "https://www.douyin.com/video/7530000000000000000"))
        let short = try XCTUnwrap(URL(string: "https://v.douyin.com/AbCdEfGh/"))
        XCTAssertTrue(adapter.matches(standard))
        XCTAssertTrue(adapter.matches(short))
        XCTAssertFalse(adapter.matches(try XCTUnwrap(URL(string: "https://www.douyin.com/user/example"))))
        XCTAssertFalse(adapter.matches(try XCTUnwrap(URL(string: "https://www.tiktok.com/@user/video/7530000000000000000"))))
        XCTAssertEqual(SiteRegistry.adapter(for: standard).siteID, .douyin)
        XCTAssertEqual(SiteRegistry.adapter(for: short).siteID, .douyin)
        XCTAssertNotEqual(SiteRegistry.adapter(for: standard).siteID, TikTokAdapter().siteID)
    }

    func testDouyinSelectsLargestMetadataThumbnailAndMergesHeaders() throws {
        let thumbnail = try XCTUnwrap(DouyinAdapter().preferredThumbnail(from: [
            "http_headers": ["Referer": "https://www.douyin.com/"],
            "thumbnails": [
                ["url": "https://example.com/360.jpeg", "width": 360, "height": 640],
                ["url": "https://example.com/1080.jpeg", "width": 1080, "height": 1920,
                 "http_headers": ["User-Agent": "douyin-thumbnail"]],
            ],
        ]))
        XCTAssertEqual(thumbnail.url.absoluteString, "https://example.com/1080.jpeg")
        XCTAssertEqual(thumbnail.headers["Referer"], "https://www.douyin.com/")
        XCTAssertEqual(thumbnail.headers["User-Agent"], "douyin-thumbnail")
    }

    func testInstagramMatchesCanonicalPostKindsAndCleansShareParameters() throws {
        let adapter = InstagramAdapter()
        for path in ["reel/Chunk8-jurw", "p/aye83DjauH", "tv/BkfuX9UB-eK"] {
            let url = try XCTUnwrap(URL(string: "https://www.instagram.com/\(path)/?igsh=abc&utm_source=share#fragment"))
            XCTAssertTrue(adapter.matches(url))
            XCTAssertEqual(adapter.canonicalURL(url).absoluteString, "https://www.instagram.com/\(path)/")
            XCTAssertEqual(SiteRegistry.adapter(for: url).siteID, .instagram)
        }
        XCTAssertFalse(adapter.matches(try XCTUnwrap(URL(string: "https://www.instagram.com/example/"))))
        XCTAssertFalse(adapter.matches(try XCTUnwrap(URL(string: "https://evil.example/reel/Chunk8-jurw/"))))
        XCTAssertFalse(adapter.matches(try XCTUnwrap(URL(string: "https://www.instagram.com/p/bad.code/"))))
    }

    func testInstagramExpandsCarouselVideosAndRecognizesUnsupportedImages() throws {
        let url = try XCTUnwrap(URL(string: "https://www.instagram.com/p/BQ0eAlwhDrw/"))
        let resources = InstagramAdapter().mediaResources(from: ["entries": [
            ["id": "video-1", "title": "Video 1", "ext": "mp4", "vcodec": "h264"],
            ["id": "image-2", "title": "Photo 2", "ext": "jpg", "vcodec": "none"],
            ["id": "video-3", "title": "Video 3", "ext": "mp4", "vcodec": "h264"],
        ]], sourceURL: url)
        XCTAssertEqual(resources.map(\.stableID), ["video-1", "image-2", "video-3"])
        XCTAssertEqual(resources.map(\.kind), [.video, .image, .video])
        XCTAssertEqual(resources.map(\.selector), [1, 2, 3])
        XCTAssertEqual(resources.map(\.isDownloadSupported), [true, false, true])
    }

    func testInstagramSingleVideoUsesRootMetadataWithoutSelector() throws {
        let url = try XCTUnwrap(URL(string: "https://www.instagram.com/reel/Chunk8-jurw/"))
        let resource = try XCTUnwrap(InstagramAdapter().mediaResources(from: [
            "id": "Chunk8-jurw", "title": "Video by instagram", "ext": "mp4",
        ], sourceURL: url).first)
        XCTAssertEqual(resource.kind, .video)
        XCTAssertNil(resource.selector)
    }

    func testInstagramSelectsHighestPixelThumbnailAndMergesHeaders() throws {
        let thumbnail = try XCTUnwrap(InstagramAdapter().preferredThumbnail(from: [
            "http_headers": ["Referer": "https://www.instagram.com/"],
            "thumbnails": [
                ["url": "https://example.com/small.jpg", "width": 320, "height": 320],
                ["url": "https://example.com/large.jpg", "width": 1080, "height": 1920,
                 "http_headers": ["User-Agent": "instagram-thumbnail"]],
            ],
        ]))
        XCTAssertEqual(thumbnail.url.absoluteString, "https://example.com/large.jpg")
        XCTAssertEqual(thumbnail.headers["Referer"], "https://www.instagram.com/")
        XCTAssertEqual(thumbnail.headers["User-Agent"], "instagram-thumbnail")
    }

    func testTelegramMatchesOnlyPublicMessageLinksAndCleansShareParameters() throws {
        let adapter = TelegramAdapter()
        for value in [
            "https://t.me/vorposte/29342?single#fragment",
            "https://telegram.me/europa_press/613?utm_source=share",
            "http://www.t.me/public_channel/42/",
        ] {
            let url = try XCTUnwrap(URL(string: value))
            XCTAssertTrue(adapter.matches(url))
            let expectedParts = url.pathComponents.filter { $0 != "/" }
            XCTAssertEqual(adapter.canonicalURL(url).absoluteString, "https://t.me/\(expectedParts[0])/\(expectedParts[1])")
            XCTAssertEqual(SiteRegistry.adapter(for: url).siteID, .telegram)
            XCTAssertEqual(adapter.classify(url), .singleVideo)
        }
        XCTAssertFalse(adapter.matches(try XCTUnwrap(URL(string: "https://t.me/public_channel"))))
        XCTAssertFalse(adapter.matches(try XCTUnwrap(URL(string: "https://t.me/+privateInvite/42"))))
        XCTAssertFalse(adapter.matches(try XCTUnwrap(URL(string: "https://t.me/c/123456"))))
        XCTAssertFalse(adapter.matches(try XCTUnwrap(URL(string: "https://t.me/joinchat/123456"))))
        XCTAssertFalse(adapter.matches(try XCTUnwrap(URL(string: "https://t.me/public_channel/not-a-message"))))
        XCTAssertFalse(adapter.matches(try XCTUnwrap(URL(string: "https://evil.example/public_channel/42"))))
    }

    func testTelegramExpandsVideosAndRecognizesImagesWithoutDownloadingThem() throws {
        let url = try XCTUnwrap(URL(string: "https://t.me/public_channel/42?single"))
        let resources = TelegramAdapter().mediaResources(from: ["entries": [
            ["id": "42", "title": "First video", "ext": "mp4"],
            ["id": "43", "title": "Photo", "ext": "jpg"],
            ["id": "44", "title": "Second video", "ext": "mp4"],
        ]], sourceURL: url)
        XCTAssertEqual(resources.map(\.stableID), ["public_channel-42", "public_channel-43", "public_channel-44"])
        XCTAssertEqual(resources.map(\.kind), [.video, .image, .video])
        XCTAssertEqual(resources.map(\.selector), [1, 2, 3])
        XCTAssertEqual(resources.map(\.isDownloadSupported), [true, false, true])
    }

    func testTelegramSingleVideoUsesRootMetadataWithoutSelector() throws {
        let url = try XCTUnwrap(URL(string: "https://t.me/europa_press/613"))
        let resource = try XCTUnwrap(TelegramAdapter().mediaResources(from: [
            "id": "613", "title": "Public video", "ext": "mp4",
        ], sourceURL: url).first)
        XCTAssertEqual(resource.stableID, "europa_press-613")
        XCTAssertEqual(resource.kind, .video)
        XCTAssertNil(resource.selector)
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
