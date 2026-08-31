import Foundation
import XCTest
@testable import SpaceDownloadNative

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
}
