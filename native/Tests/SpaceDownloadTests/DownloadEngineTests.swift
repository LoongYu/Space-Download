import Foundation
import XCTest
@testable import SpaceDownload

final class DownloadEngineTests: XCTestCase {
    func testSingleVideoSuccessEmitsProgressAndCompletes() async throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/video"))
        let executor = ScriptedProcessExecutor(results: [
            ProcessExecutionResult(exitCode: 0, lines: [#"{"id":"abc","title":"Video","thumbnail":"https://example.com/a.jpg"}"#]),
            ProcessExecutionResult(exitCode: 0, lines: [
                "[download] Destination: /tmp/video.mp4",
                "SPACEDOWNLOAD_PROGRESS:50%|1MiB/s|00:05",
                #"SPACEDOWNLOAD_RESULT:{"id":"abc","title":"Video","filepath":"/tmp/video.mp4"}"#,
            ]),
        ])
        let engine = makeEngine(executor: executor)
        engine.prepareForExecution()
        var settings = DownloadSettings.defaults
        settings.translateTitle = false
        settings.embedThumbnail = false
        let request = DownloadRequest(sourceURLs: [url], settings: settings, credentials: .init(), selectedPages: nil)
        var events: [DownloadEngineEvent] = []

        let summary = await engine.execute(request: request) { events.append($0) }

        XCTAssertEqual(summary.completed, 1)
        XCTAssertTrue(summary.failures.isEmpty)
        XCTAssertTrue(events.contains(.itemProgress(0.5, speed: "1MiB/s", eta: "00:05")))
        XCTAssertTrue(events.contains(.log("[下载] [download] Destination: /tmp/video.mp4")))
        XCTAssertFalse(events.contains { event in
            if case let .log(message) = event { return message.contains("[下载进度]") }
            return false
        })
        XCTAssertTrue(events.contains(.log("[下载] 文件已写入：/tmp/video.mp4")))
        XCTAssertTrue(events.contains(.itemSucceeded(title: "Video", url: url)))
    }

    func testDownloadFailureKeepsTitleAndURL() async throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/unavailable"))
        let executor = ScriptedProcessExecutor(results: [
            ProcessExecutionResult(exitCode: 0, lines: [#"{"id":"abc","title":"Unavailable"}"#]),
            ProcessExecutionResult(exitCode: 1, lines: ["ERROR: Video unavailable"]),
        ])
        let engine = makeEngine(executor: executor)
        engine.prepareForExecution()
        var settings = DownloadSettings.defaults
        settings.translateTitle = false
        settings.embedThumbnail = false

        let summary = await engine.execute(
            request: DownloadRequest(sourceURLs: [url], settings: settings, credentials: .init(), selectedPages: nil),
            onEvent: { _ in }
        )

        XCTAssertEqual(summary.completed, 0)
        XCTAssertEqual(summary.failures.first?.title, "Unavailable")
        XCTAssertEqual(summary.failures.first?.url, url)
        XCTAssertTrue(summary.failures.first?.reason.contains("Video unavailable") == true)
    }

    func testYouTubeBotCheckFailureProvidesSafeActionableMessage() async throws {
        let url = try XCTUnwrap(URL(string: "https://www.youtube.com/watch?v=abc12345678"))
        let executor = ScriptedProcessExecutor(results: [
            ProcessExecutionResult(
                exitCode: 1,
                lines: ["ERROR: Sign in to confirm you’re not a bot. Use --cookies-from-browser or --cookies"]
            ),
        ])
        let engine = makeEngine(executor: executor)
        engine.prepareForExecution()

        let summary = await engine.execute(
            request: DownloadRequest(sourceURLs: [url], settings: .defaults, credentials: .init(), selectedPages: nil),
            onEvent: { _ in }
        )

        let reason = try XCTUnwrap(summary.failures.first?.reason)
        XCTAssertTrue(reason.contains("YouTube 拒绝了当前网络的匿名访问"))
        XCTAssertTrue(reason.contains("手动选择 cookies.txt"))
        XCTAssertFalse(reason.contains("cookies-from-browser"))
    }

    func testPornhubRequestUsesAutomaticCookies() async throws {
        let url = try XCTUnwrap(URL(string: "https://www.pornhub.com/view_video.php?viewkey=abc"))
        let executor = ScriptedProcessExecutor(results: [
            ProcessExecutionResult(exitCode: 0, lines: [#"{"id":"abc","title":"Video"}"#]),
            ProcessExecutionResult(exitCode: 0, lines: [#"SPACEDOWNLOAD_RESULT:{"filepath":"/tmp/video.mp4"}"#]),
        ])
        let engine = makeEngine(executor: executor)
        engine.prepareForExecution()
        var settings = DownloadSettings.defaults
        settings.translateTitle = false
        settings.embedThumbnail = false

        _ = await engine.execute(
            request: DownloadRequest(sourceURLs: [url], settings: settings, credentials: .init(), selectedPages: nil),
            onEvent: { _ in }
        )

        let arguments = executor.recordedArguments.flatMap { $0 }
        XCTAssertTrue(arguments.contains("--cookies"))
        XCTAssertTrue(arguments.contains { $0.hasSuffix("pornhub-cookies.txt") })
    }

    func testThumbnailRunsOnlyAfterSuccessfulVideo() async throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/video"))
        let thumbnail = RecordingThumbnailService()
        let executor = ScriptedProcessExecutor(results: [
            ProcessExecutionResult(exitCode: 0, lines: [#"{"id":"abc","title":"Video","thumbnail":"https://example.com/a.jpg","http_headers":{"Referer":"https://www.pornhub.com/","Origin":"https://www.pornhub.com"}}"#]),
            ProcessExecutionResult(exitCode: 0, lines: [#"SPACEDOWNLOAD_RESULT:{"filepath":"/tmp/video.mp4"}"#]),
        ])
        let engine = DownloadEngine(
            tools: ToolLocations(ytDlp: URL(fileURLWithPath: "/usr/bin/true"), ffmpeg: nil),
            executor: executor,
            translator: IdentityTitleTranslator(),
            thumbnailService: thumbnail,
            metadataLogger: DisabledMetadataDebugLogger()
        )
        engine.prepareForExecution()
        var settings = DownloadSettings.defaults
        settings.translateTitle = false

        let summary = await engine.execute(
            request: DownloadRequest(sourceURLs: [url], settings: settings, credentials: .init(), selectedPages: nil),
            onEvent: { _ in }
        )

        XCTAssertEqual(summary.completed, 1)
        XCTAssertEqual(thumbnail.downloadCount, 1)
        XCTAssertEqual(thumbnail.lastHeaders?["Referer"], "https://www.pornhub.com/")
        XCTAssertEqual(thumbnail.lastHeaders?["Origin"], "https://www.pornhub.com")
    }

    func testEmptyCollectionIsReportedAsFailure() async throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/channel/test"))
        let executor = ScriptedProcessExecutor(results: [
            ProcessExecutionResult(exitCode: 0, lines: [#"{"entries":[]}"#]),
        ])
        let engine = makeEngine(executor: executor)
        engine.prepareForExecution()
        var settings = DownloadSettings.defaults
        settings.translateTitle = false
        settings.embedThumbnail = false

        let summary = await engine.execute(
            request: DownloadRequest(sourceURLs: [url], settings: settings, credentials: .init(), selectedPages: nil),
            onEvent: { _ in }
        )

        XCTAssertEqual(summary.completed, 0)
        XCTAssertEqual(summary.failures.count, 1)
        XCTAssertEqual(summary.failures.first?.reason, "未获取到可下载的视频链接")
    }

    func testExistingVideoIDSkipsWithoutCallingYtDlp() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let existingFile = directory.appendingPathComponent("Existing title(abc123).mp4")
        try Data().write(to: existingFile)
        let url = try XCTUnwrap(URL(string: "https://www.pornhub.com/view_video.php?viewkey=abc123"))
        let executor = ScriptedProcessExecutor(results: [])
        let engine = makeEngine(executor: executor)
        engine.prepareForExecution()
        var settings = DownloadSettings.defaults
        settings.downloadPath = directory.path
        var events: [DownloadEngineEvent] = []

        let summary = await engine.execute(
            request: DownloadRequest(sourceURLs: [url], settings: settings, credentials: .init(), selectedPages: nil),
            onEvent: { events.append($0) }
        )

        XCTAssertEqual(summary.completed, 1)
        XCTAssertTrue(executor.recordedArguments.isEmpty)
        let skippedEvent = try XCTUnwrap(events.first { event in
            if case .itemSkipped = event { return true }
            return false
        })
        guard case let .itemSkipped(title, skippedURL, foundFile) = skippedEvent else {
            return XCTFail("Expected skipped event")
        }
        XCTAssertEqual(title, "Existing title(abc123)")
        XCTAssertEqual(skippedURL, url)
        XCTAssertEqual(foundFile.resolvingSymlinksInPath(), existingFile.resolvingSymlinksInPath())
    }

    func testYouTubePlaylistExpandsFlatEntriesAndDownloadsEachVideo() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let playlistURL = try XCTUnwrap(URL(string: "https://www.youtube.com/playlist?list=PL123"))
        let executor = ScriptedProcessExecutor(results: [
            ProcessExecutionResult(exitCode: 0, lines: [
                #"{"entries":[{"id":"abc12345678","title":"One"},{"id":"def12345678","title":"Two"}]}"#,
            ]),
            ProcessExecutionResult(exitCode: 0, lines: [#"{"id":"abc12345678","title":"One"}"#]),
            ProcessExecutionResult(exitCode: 0, lines: [
                #"SPACEDOWNLOAD_RESULT:{"filepath":"/tmp/one.mp4"}"#,
            ]),
            ProcessExecutionResult(exitCode: 0, lines: [#"{"id":"def12345678","title":"Two"}"#]),
            ProcessExecutionResult(exitCode: 0, lines: [
                #"SPACEDOWNLOAD_RESULT:{"filepath":"/tmp/two.mp4"}"#,
            ]),
        ])
        let engine = makeEngine(executor: executor)
        engine.prepareForExecution()
        var settings = DownloadSettings.defaults
        settings.downloadPath = directory.path
        settings.translateTitle = false
        settings.embedThumbnail = false
        settings.sites.youtube.requestIntervalSeconds = 0

        let summary = await engine.execute(
            request: DownloadRequest(
                sourceURLs: [playlistURL],
                settings: settings,
                credentials: .init(),
                selectedPages: nil,
                youtubePlaylistItems: [1, 2]
            ),
            onEvent: { _ in }
        )

        XCTAssertEqual(summary.completed, 2)
        XCTAssertTrue(summary.failures.isEmpty)
        XCTAssertEqual(executor.recordedArguments.count, 5)
        XCTAssertTrue(executor.recordedArguments[0].contains("--flat-playlist"))
        XCTAssertTrue(executor.recordedArguments[0].contains("--playlist-items"))
        let allArguments = executor.recordedArguments.flatMap { $0 }
        XCTAssertTrue(allArguments.contains("https://www.youtube.com/watch?v=abc12345678"))
        XCTAssertTrue(allArguments.contains("https://www.youtube.com/watch?v=def12345678"))
    }

    func testYouTubeMediaOptionsDoNotReusePornhubOptions() async throws {
        let url = try XCTUnwrap(URL(string: "https://www.youtube.com/watch?v=abc12345678"))
        let executor = ScriptedProcessExecutor(results: [
            ProcessExecutionResult(
                exitCode: 0,
                lines: [#"{"id":"abc12345678","title":"Video","thumbnail":"https://example.com/a.jpg"}"#]
            ),
            ProcessExecutionResult(
                exitCode: 0,
                lines: [#"SPACEDOWNLOAD_RESULT:{"filepath":"/tmp/video.mp4"}"#]
            ),
        ])
        let translator = RecordingTitleTranslator()
        let thumbnail = RecordingThumbnailService()
        let engine = DownloadEngine(
            tools: ToolLocations(ytDlp: URL(fileURLWithPath: "/usr/bin/true"), ffmpeg: nil),
            executor: executor,
            translator: translator,
            thumbnailService: thumbnail,
            metadataLogger: DisabledMetadataDebugLogger()
        )
        engine.prepareForExecution()
        var settings = DownloadSettings.defaults
        settings.sites.pornhub.media.translateTitle = true
        settings.sites.pornhub.media.embedThumbnail = true
        settings.sites.youtube.media.translateTitle = false
        settings.sites.youtube.media.embedThumbnail = false
        settings.sites.youtube.requestIntervalSeconds = 0

        let summary = await engine.execute(
            request: DownloadRequest(
                sourceURLs: [url],
                settings: settings,
                credentials: .init(),
                selectedPages: nil
            ),
            onEvent: { _ in }
        )

        XCTAssertEqual(summary.completed, 1)
        XCTAssertEqual(translator.translationCount, 0)
        XCTAssertEqual(thumbnail.downloadCount, 0)
    }

    func testYouTubeDownloadUsesHighestResolutionThumbnail() async throws {
        let url = try XCTUnwrap(URL(string: "https://www.youtube.com/watch?v=abc12345678"))
        let executor = ScriptedProcessExecutor(results: [
            ProcessExecutionResult(exitCode: 0, lines: [
                #"{"id":"abc12345678","title":"Video","thumbnail":"https://i.ytimg.com/default.jpg","http_headers":{"Referer":"https://www.youtube.com/"},"thumbnails":[{"url":"https://i.ytimg.com/low.jpg","width":320,"height":180},{"url":"https://i.ytimg.com/max.jpg","width":1920,"height":1080,"http_headers":{"User-Agent":"thumbnail-agent"}}]}"#,
            ]),
            ProcessExecutionResult(exitCode: 0, lines: [
                #"SPACEDOWNLOAD_RESULT:{"filepath":"/tmp/video.mp4"}"#,
            ]),
        ])
        let thumbnail = RecordingThumbnailService()
        let engine = DownloadEngine(
            tools: ToolLocations(ytDlp: URL(fileURLWithPath: "/usr/bin/true"), ffmpeg: nil),
            executor: executor,
            translator: IdentityTitleTranslator(),
            thumbnailService: thumbnail,
            metadataLogger: DisabledMetadataDebugLogger()
        )
        engine.prepareForExecution()
        var settings = DownloadSettings.defaults
        settings.sites.youtube.media.translateTitle = false
        settings.sites.youtube.media.embedThumbnail = true
        settings.sites.youtube.requestIntervalSeconds = 0
        var events: [DownloadEngineEvent] = []

        let summary = await engine.execute(
            request: DownloadRequest(
                sourceURLs: [url],
                settings: settings,
                credentials: .init(),
                selectedPages: nil
            ),
            onEvent: { events.append($0) }
        )

        XCTAssertEqual(summary.completed, 1)
        XCTAssertEqual(thumbnail.lastSourceURL?.absoluteString, "https://i.ytimg.com/max.jpg")
        XCTAssertEqual(thumbnail.lastHeaders?["Referer"], "https://www.youtube.com/")
        XCTAssertEqual(thumbnail.lastHeaders?["User-Agent"], "thumbnail-agent")
        XCTAssertTrue(events.contains(.log("封面选择：1920×1080")))
    }

    func testXPostExpandsAndDownloadsEveryVideoResourceWithLiveProgress() async throws {
        let url = try XCTUnwrap(URL(string: "https://x.com/example/status/1234567890"))
        let executor = ScriptedProcessExecutor(results: [
            ProcessExecutionResult(exitCode: 0, lines: [#"{"_type":"playlist","entries":[{"id":"1234567890-1","title":"clip","ext":"mp4"},{"id":"1234567890-2","title":"gif","format":"animated gif","ext":"mp4"},{"id":"1234567890-2","title":"duplicate","ext":"mp4"}]}"#]),
            ProcessExecutionResult(exitCode: 0, lines: ["SPACEDOWNLOAD_PROGRESS:25%|2MiB/s|00:03", #"SPACEDOWNLOAD_RESULT:{"filepath":"/tmp/clip.mp4"}"#]),
            ProcessExecutionResult(exitCode: 0, lines: [#"SPACEDOWNLOAD_RESULT:{"filepath":"/tmp/gif.mp4"}"#]),
        ])
        let engine = makeEngine(executor: executor)
        engine.prepareForExecution()
        var settings = DownloadSettings.defaults
        settings.sites.x.media.translateTitle = false
        settings.sites.x.media.embedThumbnail = false
        var events: [DownloadEngineEvent] = []

        let summary = await engine.execute(request: DownloadRequest(
            sourceURLs: [url], settings: settings, credentials: .init(), selectedPages: nil
        )) { events.append($0) }

        XCTAssertEqual(summary.completed, 2)
        XCTAssertTrue(summary.failures.isEmpty)
        XCTAssertTrue(events.contains(.prepared(total: 2)))
        XCTAssertTrue(events.contains(.itemProgress(0.25, speed: "2MiB/s", eta: "00:03")))
        XCTAssertTrue(events.contains(.log("重复媒体 ID 1234567890-2，已跳过并继续后续任务")))
        XCTAssertEqual(executor.recordedArguments.count, 3)
        XCTAssertTrue(executor.recordedArguments[0].contains("--yes-playlist"))
        XCTAssertTrue(executor.recordedArguments[1].contains("1"))
        XCTAssertTrue(executor.recordedArguments[2].contains("2"))
    }

    func testInstagramCarouselDownloadsVideosReportsImageAndContinuesAfterFailure() async throws {
        let url = try XCTUnwrap(URL(string: "https://www.instagram.com/p/BQ0eAlwhDrw/?igsh=share"))
        let executor = ScriptedProcessExecutor(results: [
            ProcessExecutionResult(exitCode: 0, lines: [#"{"_type":"playlist","entries":[{"id":"video-1","title":"first","ext":"mp4"},{"id":"image-2","title":"photo","ext":"jpg"},{"id":"video-3","title":"third","ext":"mp4"}]}"#]),
            ProcessExecutionResult(exitCode: 1, lines: ["ERROR: first failed"]),
            ProcessExecutionResult(exitCode: 0, lines: ["SPACEDOWNLOAD_PROGRESS:75%|3MiB/s|00:01", #"SPACEDOWNLOAD_RESULT:{"filepath":"/tmp/third.mp4"}"#]),
        ])
        let engine = makeEngine(executor: executor)
        engine.prepareForExecution()
        var settings = DownloadSettings.defaults
        settings.sites.instagram.media.translateTitle = false
        settings.sites.instagram.media.embedThumbnail = false
        var events: [DownloadEngineEvent] = []

        let summary = await engine.execute(request: DownloadRequest(
            sourceURLs: [url], settings: settings, credentials: .init(), selectedPages: nil
        )) { events.append($0) }

        XCTAssertEqual(summary.completed, 1)
        XCTAssertEqual(summary.failures.count, 2)
        XCTAssertTrue(summary.failures.contains { $0.reason.contains("尚未验证 Instagram 图片下载") })
        XCTAssertTrue(summary.failures.contains { $0.reason.contains("first failed") })
        XCTAssertTrue(events.contains(.prepared(total: 3)))
        XCTAssertTrue(events.contains(.itemProgress(0.75, speed: "3MiB/s", eta: "00:01")))
        XCTAssertEqual(executor.recordedArguments.count, 3)
        XCTAssertEqual(executor.recordedArguments[0].last, "https://www.instagram.com/p/BQ0eAlwhDrw/")
        XCTAssertFalse(events.compactMap { event -> String? in
            if case let .log(message) = event { return message }
            return nil
        }.contains { $0.contains("[下载进度]") })
    }

    func testTelegramMessageExpandsEachVideoAndSkipsRecognizedImage() async throws {
        let url = try XCTUnwrap(URL(string: "https://telegram.me/channel_name/42?single"))
        let executor = ScriptedProcessExecutor(results: [
            ProcessExecutionResult(exitCode: 0, lines: [#"{"_type":"playlist","entries":[{"id":"42","title":"first","ext":"mp4","upload_date":"20260831"},{"id":"43","title":"photo","ext":"jpg"},{"id":"44","title":"third","ext":"mp4","upload_date":"20260831"}]}"#]),
            ProcessExecutionResult(exitCode: 0, lines: [#"SPACEDOWNLOAD_RESULT:{"filepath":"/tmp/first.mp4"}"#]),
            ProcessExecutionResult(exitCode: 0, lines: [#"SPACEDOWNLOAD_RESULT:{"filepath":"/tmp/third.mp4"}"#]),
        ])
        let engine = makeEngine(executor: executor)
        engine.prepareForExecution()
        var settings = DownloadSettings.defaults
        settings.sites.telegram.media.embedThumbnail = false
        var events: [DownloadEngineEvent] = []

        let summary = await engine.execute(request: DownloadRequest(
            sourceURLs: [url], settings: settings, credentials: .init(), selectedPages: nil
        )) { events.append($0) }

        XCTAssertEqual(summary.completed, 2)
        XCTAssertEqual(summary.failures.count, 1)
        XCTAssertTrue(summary.failures[0].reason.contains("尚未验证 Telegram 图片下载"))
        XCTAssertTrue(events.contains(.prepared(total: 3)))
        XCTAssertEqual(executor.recordedArguments.count, 3)
        XCTAssertEqual(executor.recordedArguments[0].last, "https://t.me/channel_name/42")
        XCTAssertEqual(executor.recordedArguments[1][try XCTUnwrap(executor.recordedArguments[1].firstIndex(of: "--playlist-items")) + 1], "1")
        XCTAssertEqual(executor.recordedArguments[2][try XCTUnwrap(executor.recordedArguments[2].firstIndex(of: "--playlist-items")) + 1], "3")
    }
}

final class ScriptedProcessExecutor: ProcessExecuting {
    private let lock = NSLock()
    private var results: [ProcessExecutionResult]
    private var calls: [[String]] = []

    init(results: [ProcessExecutionResult]) {
        self.results = results
    }

    func run(executable: URL, arguments: [String], onLine: @escaping (String) -> Void) async -> ProcessExecutionResult {
        let result = lock.withLock {
            calls.append(arguments)
            return results.isEmpty
                ? ProcessExecutionResult(exitCode: -1, lines: ["missing scripted result"])
                : results.removeFirst()
        }
        result.lines.forEach(onLine)
        return result
    }

    func cancel() {}

    var recordedArguments: [[String]] {
        lock.withLock { calls }
    }
}

final class RecordingThumbnailService: ThumbnailDownloading {
    private let lock = NSLock()
    private var count = 0
    private var recordedHeaders: [String: String]?
    private var recordedSourceURL: URL?

    var downloadCount: Int { lock.withLock { count } }
    var lastHeaders: [String: String]? { lock.withLock { recordedHeaders } }
    var lastSourceURL: URL? { lock.withLock { recordedSourceURL } }

    func download(from sourceURL: URL, beside videoURL: URL, headers: [String: String]) async throws -> URL {
        lock.withLock {
            count += 1
            recordedHeaders = headers
            recordedSourceURL = sourceURL
        }
        return videoURL.deletingPathExtension().appendingPathExtension("jpg")
    }
}

final class RecordingTitleTranslator: TitleTranslating {
    private let lock = NSLock()
    private var count = 0

    var translationCount: Int { lock.withLock { count } }

    func translate(_ text: String) async -> String {
        lock.withLock { count += 1 }
        return "翻译：\(text)"
    }
}
