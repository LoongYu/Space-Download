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

    var downloadCount: Int { lock.withLock { count } }
    var lastHeaders: [String: String]? { lock.withLock { recordedHeaders } }

    func download(from sourceURL: URL, beside videoURL: URL, headers: [String: String]) async throws -> URL {
        lock.withLock {
            count += 1
            recordedHeaders = headers
        }
        return videoURL.deletingPathExtension().appendingPathExtension("jpg")
    }
}
