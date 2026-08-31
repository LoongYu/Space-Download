import Foundation
import XCTest
@testable import SpaceDownload

final class YtDlpCommandBuilderTests: XCTestCase {
    func testBuildsDownloadArgumentsFromAllSettings() throws {
        var settings = DownloadSettings.defaults
        settings.downloadPath = "/tmp/downloads"
        settings.quality = .hd
        settings.outputFormat = .mkv
        settings.common.rateLimit = .fiveMB
        settings.common.concurrentFragments = 4
        settings.useProxy = true
        settings.proxyURL = "http://127.0.0.1:7890"
        settings.username = "user"
        settings.useCookies = true
        let cookieURL = URL(fileURLWithPath: "/tmp/cookies.txt")
        let url = try XCTUnwrap(URL(string: "https://www.pornhub.com/view_video.php?viewkey=abc"))
        let request = DownloadRequest(
            sourceURLs: [url],
            settings: settings,
            credentials: DownloadCredentials(password: "secret", cookiesFileURL: cookieURL),
            selectedPages: nil
        )
        let builder = YtDlpCommandBuilder(tools: ToolLocations(
            ytDlp: URL(fileURLWithPath: "/usr/bin/yt-dlp"),
            ffmpeg: URL(fileURLWithPath: "/usr/bin/ffmpeg")
        ))
        let arguments = builder.downloadArguments(
            for: DownloadItem(url: url, title: "Old", page: nil, pageIndex: nil),
            request: request,
            temporaryDirectory: URL(fileURLWithPath: "/tmp/work"),
            translatedTitle: "新标题"
        )

        XCTAssertTrue(arguments.contains("bestvideo[height<=720]+bestaudio/best[height<=720]"))
        XCTAssertTrue(arguments.contains("http://127.0.0.1:7890"))
        XCTAssertTrue(arguments.contains(cookieURL.path))
        XCTAssertTrue(arguments.contains("secret"))
        XCTAssertTrue(arguments.contains("https://www.pornhub.com/"))
        XCTAssertTrue(arguments.contains("新标题"))
        let replacementIndex = try XCTUnwrap(arguments.firstIndex(of: "--replace-in-metadata"))
        XCTAssertEqual(arguments[replacementIndex + 1], "pre_process:title")
        XCTAssertEqual(arguments[replacementIndex + 2], "^.*$")
        XCTAssertEqual(arguments[replacementIndex + 3], "新标题")
        XCTAssertTrue(arguments.contains("5M"))
        let fragmentsIndex = try XCTUnwrap(arguments.firstIndex(of: "--concurrent-fragments"))
        XCTAssertEqual(arguments[fragmentsIndex + 1], "4")
        XCTAssertTrue(arguments.contains("5"))
        XCTAssertTrue(arguments.contains("--progress"))
    }

    func testBuildsYouTubeSpecificArgumentsWithoutPornhubCredentials() throws {
        var settings = DownloadSettings.defaults
        settings.sites.pornhub.username = "pornhub-user"
        settings.sites.youtube.codecPreference = .h264
        settings.sites.youtube.subtitleMode = .manualAndAuto
        settings.sites.youtube.subtitleLanguages = "zh-Hans,en.*"
        settings.sites.youtube.requestIntervalSeconds = 5
        settings.sites.youtube.media.filenameTemplate = .title
        let youtubeCookies = URL(fileURLWithPath: "/tmp/youtube-cookies.txt")
        let url = try XCTUnwrap(URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"))
        let request = DownloadRequest(
            sourceURLs: [url],
            settings: settings,
            credentials: DownloadCredentials(
                password: "pornhub-password",
                cookiesFileURL: URL(fileURLWithPath: "/tmp/pornhub-cookies.txt"),
                youtubeCookiesFileURL: youtubeCookies
            ),
            selectedPages: nil
        )
        let builder = YtDlpCommandBuilder(tools: ToolLocations(
            ytDlp: URL(fileURLWithPath: "/usr/bin/yt-dlp"),
            ffmpeg: nil
        ))

        let arguments = builder.downloadArguments(
            for: DownloadItem(url: url, title: "Video", page: nil, pageIndex: nil),
            request: request,
            temporaryDirectory: URL(fileURLWithPath: "/tmp/work"),
            translatedTitle: "中文标题"
        )

        XCTAssertTrue(arguments.contains(youtubeCookies.path))
        XCTAssertTrue(arguments.contains("vcodec:h264"))
        XCTAssertTrue(arguments.contains("--write-subs"))
        XCTAssertTrue(arguments.contains("--write-auto-subs"))
        XCTAssertTrue(arguments.contains("zh-Hans,en.*"))
        XCTAssertTrue(arguments.contains("--sleep-interval"))
        XCTAssertTrue(arguments.contains("--ignore-config"))
        let proxyIndex = try XCTUnwrap(arguments.firstIndex(of: "--proxy"))
        XCTAssertEqual(arguments[proxyIndex + 1], "")
        XCTAssertFalse(arguments.contains("--user-agent"))
        XCTAssertFalse(arguments.contains("pornhub-user"))
        XCTAssertFalse(arguments.contains("pornhub-password"))
        XCTAssertFalse(arguments.contains("https://www.pornhub.com/"))
        let outputIndex = try XCTUnwrap(arguments.firstIndex(of: "--output"))
        XCTAssertEqual(arguments[outputIndex + 1], "%(title)s(%(id)s).%(ext)s")
        let replacementIndex = try XCTUnwrap(arguments.firstIndex(of: "--replace-in-metadata"))
        XCTAssertEqual(arguments[replacementIndex + 1], "pre_process:title")
        XCTAssertEqual(arguments[replacementIndex + 2], "^.*$")
        XCTAssertEqual(arguments[replacementIndex + 3], "中文标题")
    }

    func testBuildsYouTubePlaylistItemSelection() throws {
        let url = try XCTUnwrap(URL(string: "https://www.youtube.com/playlist?list=PL123"))
        let request = DownloadRequest(
            sourceURLs: [url],
            settings: .defaults,
            credentials: .init(),
            selectedPages: nil,
            youtubePlaylistItems: [1, 3, 4]
        )
        let arguments = YtDlpCommandBuilder(tools: ToolLocations(
            ytDlp: URL(fileURLWithPath: "/usr/bin/yt-dlp"),
            ffmpeg: nil
        )).collectionArguments(for: url, request: request)

        let selectionIndex = try XCTUnwrap(arguments.firstIndex(of: "--playlist-items"))
        XCTAssertEqual(arguments[selectionIndex + 1], "1,3,4")
        XCTAssertTrue(arguments.contains("--flat-playlist"))
    }

    func testBuildsXResourceSelectionAndUsesOnlyXCookies() throws {
        let url = try XCTUnwrap(URL(string: "https://x.com/example/status/1234567890"))
        let metadata = try JSONSerialization.data(withJSONObject: ["id": "1234567890-2"])
        let item = DownloadItem(url: url, title: "post", page: nil, pageIndex: 2, resource: MediaResourceTask(
            stableID: "1234567890-2", kind: .animatedGIF, selector: 2, metadataJSON: metadata
        ))
        let xCookies = URL(fileURLWithPath: "/tmp/x-cookies.txt")
        let request = DownloadRequest(sourceURLs: [url], settings: .defaults, credentials: DownloadCredentials(
            cookiesFileURL: URL(fileURLWithPath: "/tmp/pornhub.txt"),
            youtubeCookiesFileURL: URL(fileURLWithPath: "/tmp/youtube.txt"),
            xCookiesFileURL: xCookies
        ), selectedPages: nil)
        let arguments = YtDlpCommandBuilder(tools: ToolLocations(
            ytDlp: URL(fileURLWithPath: "/usr/bin/yt-dlp"), ffmpeg: nil
        )).downloadArguments(for: item, request: request, temporaryDirectory: URL(fileURLWithPath: "/tmp/work"))

        XCTAssertTrue(arguments.contains("--yes-playlist"))
        let index = try XCTUnwrap(arguments.firstIndex(of: "--playlist-items"))
        XCTAssertEqual(arguments[index + 1], "2")
        XCTAssertTrue(arguments.contains(xCookies.path))
        XCTAssertFalse(arguments.contains("/tmp/pornhub.txt"))
        XCTAssertFalse(arguments.contains("/tmp/youtube.txt"))
        XCTAssertFalse(arguments.contains("--cookies-from-browser"))
    }

    func testBuildsTikTokSingleVideoCommandWithIndependentSettingsAndCookies() throws {
        var settings = DownloadSettings.defaults
        settings.sites.tiktok.media.filenameTemplate = .uploaderDateTitle
        let url = try XCTUnwrap(URL(string: "https://www.tiktok.com/@scout2015/video/6718335390845095173"))
        let cookies = URL(fileURLWithPath: "/tmp/tiktok.txt")
        let request = DownloadRequest(sourceURLs: [url], settings: settings, credentials: DownloadCredentials(
            cookiesFileURL: URL(fileURLWithPath: "/tmp/pornhub.txt"),
            youtubeCookiesFileURL: URL(fileURLWithPath: "/tmp/youtube.txt"),
            xCookiesFileURL: URL(fileURLWithPath: "/tmp/x.txt"),
            tiktokCookiesFileURL: cookies
        ), selectedPages: nil)
        let arguments = YtDlpCommandBuilder(tools: ToolLocations(
            ytDlp: URL(fileURLWithPath: "/usr/bin/yt-dlp"), ffmpeg: nil
        )).downloadArguments(for: DownloadItem(url: url, title: "post", page: nil, pageIndex: nil),
                             request: request, temporaryDirectory: URL(fileURLWithPath: "/tmp/work"))

        XCTAssertTrue(arguments.contains("--no-playlist"))
        XCTAssertTrue(arguments.contains(cookies.path))
        XCTAssertFalse(arguments.contains("/tmp/pornhub.txt"))
        XCTAssertFalse(arguments.contains("/tmp/youtube.txt"))
        XCTAssertFalse(arguments.contains("/tmp/x.txt"))
        XCTAssertFalse(arguments.contains("--cookies-from-browser"))
        let output = try XCTUnwrap(arguments.firstIndex(of: "--output"))
        XCTAssertEqual(arguments[output + 1], "%(uploader)s/%(upload_date)s-%(title)s(%(id)s).%(ext)s")
    }

    func testBuildsDouyinCommandWithIndependentSettingsAndCookies() throws {
        var settings = DownloadSettings.defaults
        settings.sites.douyin.media.filenameTemplate = .dateTitle
        let url = try XCTUnwrap(URL(string: "https://www.douyin.com/video/7530000000000000000"))
        let douyinCookies = URL(fileURLWithPath: "/tmp/douyin.txt")
        let request = DownloadRequest(sourceURLs: [url], settings: settings, credentials: DownloadCredentials(
            cookiesFileURL: URL(fileURLWithPath: "/tmp/pornhub.txt"),
            youtubeCookiesFileURL: URL(fileURLWithPath: "/tmp/youtube.txt"),
            xCookiesFileURL: URL(fileURLWithPath: "/tmp/x.txt"),
            tiktokCookiesFileURL: URL(fileURLWithPath: "/tmp/tiktok.txt"),
            douyinCookiesFileURL: douyinCookies
        ), selectedPages: nil)
        let arguments = YtDlpCommandBuilder(tools: ToolLocations(
            ytDlp: URL(fileURLWithPath: "/usr/bin/yt-dlp"), ffmpeg: nil
        )).downloadArguments(for: DownloadItem(url: url, title: "抖音", page: nil, pageIndex: nil),
                             request: request, temporaryDirectory: URL(fileURLWithPath: "/tmp/work"))

        XCTAssertTrue(arguments.contains(douyinCookies.path))
        XCTAssertFalse(arguments.contains("/tmp/tiktok.txt"))
        XCTAssertFalse(arguments.contains("--cookies-from-browser"))
        XCTAssertFalse(arguments.contains("--impersonate"))
        let output = try XCTUnwrap(arguments.firstIndex(of: "--output"))
        XCTAssertEqual(arguments[output + 1], "%(upload_date)s-%(title)s(%(id)s).%(ext)s")
    }

    func testBuildsInstagramSelectorWithCanonicalURLAndOnlyInstagramCookies() throws {
        let url = try XCTUnwrap(URL(string: "https://instagram.com/p/BQ0eAlwhDrw/?igsh=share&utm_source=x"))
        let metadata = try JSONSerialization.data(withJSONObject: ["id": "BQ0dTpOhuHT", "ext": "mp4"])
        let item = DownloadItem(url: url, title: "Video", page: nil, pageIndex: 2, resource: MediaResourceTask(
            stableID: "BQ0dTpOhuHT", kind: .video, selector: 2, metadataJSON: metadata
        ))
        let cookies = URL(fileURLWithPath: "/tmp/instagram.txt")
        let request = DownloadRequest(sourceURLs: [url], settings: .defaults, credentials: DownloadCredentials(
            cookiesFileURL: URL(fileURLWithPath: "/tmp/pornhub.txt"),
            xCookiesFileURL: URL(fileURLWithPath: "/tmp/x.txt"),
            instagramCookiesFileURL: cookies
        ), selectedPages: nil)
        let arguments = YtDlpCommandBuilder(tools: ToolLocations(
            ytDlp: URL(fileURLWithPath: "/usr/bin/yt-dlp"), ffmpeg: nil
        )).downloadArguments(for: item, request: request, temporaryDirectory: URL(fileURLWithPath: "/tmp/work"))

        XCTAssertEqual(arguments.last, "https://www.instagram.com/p/BQ0eAlwhDrw/")
        XCTAssertEqual(arguments[try XCTUnwrap(arguments.firstIndex(of: "--playlist-items")) + 1], "2")
        XCTAssertTrue(arguments.contains(cookies.path))
        XCTAssertFalse(arguments.contains("/tmp/pornhub.txt"))
        XCTAssertFalse(arguments.contains("/tmp/x.txt"))
        XCTAssertFalse(arguments.contains("--cookies-from-browser"))
    }
}
