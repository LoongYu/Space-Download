import Foundation
import XCTest
@testable import SpaceDownload

final class YtDlpCommandBuilderTests: XCTestCase {
    func testBuildsDownloadArgumentsFromAllSettings() throws {
        var settings = DownloadSettings.defaults
        settings.downloadPath = "/tmp/downloads"
        settings.quality = .hd
        settings.outputFormat = .mkv
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
        settings.sites.youtube.authenticationMode = .cookiesFile
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
            temporaryDirectory: URL(fileURLWithPath: "/tmp/work")
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

    func testBuildsYouTubeChromeAuthenticationArguments() throws {
        var settings = DownloadSettings.defaults
        settings.sites.youtube.authenticationMode = .chrome
        let url = try XCTUnwrap(URL(string: "https://www.youtube.com/watch?v=G1LObB-BYEs"))
        let request = DownloadRequest(
            sourceURLs: [url],
            settings: settings,
            credentials: DownloadCredentials(
                youtubeCookiesFileURL: URL(fileURLWithPath: "/tmp/stale-cookies.txt")
            ),
            selectedPages: nil
        )

        let arguments = YtDlpCommandBuilder(tools: ToolLocations(
            ytDlp: URL(fileURLWithPath: "/usr/bin/yt-dlp"),
            ffmpeg: nil
        )).metadataArguments(for: url, request: request)

        let browserIndex = try XCTUnwrap(arguments.firstIndex(of: "--cookies-from-browser"))
        XCTAssertEqual(arguments[browserIndex + 1], "chrome")
        XCTAssertFalse(arguments.contains("--cookies"))
        XCTAssertFalse(arguments.contains("/tmp/stale-cookies.txt"))
    }
}
