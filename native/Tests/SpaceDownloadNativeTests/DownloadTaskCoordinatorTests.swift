import Foundation
import XCTest
@testable import SpaceDownloadNative

@MainActor
final class DownloadTaskCoordinatorTests: XCTestCase {
    func testStartAndStopStateFlow() async throws {
        let executor = BlockingProcessExecutor()
        let coordinator = DownloadTaskCoordinator(engine: makeEngine(executor: executor))
        let url = try XCTUnwrap(URL(string: "https://example.com/video"))

        coordinator.start(request: makeRequest(urls: [url]))
        XCTAssertEqual(coordinator.status, .running)
        XCTAssertEqual(coordinator.pendingURLs, [url])

        coordinator.stop()
        XCTAssertEqual(coordinator.status, .stopping)
        for _ in 0..<20 where coordinator.status != .idle {
            await Task.yield()
        }
        XCTAssertEqual(coordinator.status, .idle)
        XCTAssertTrue(coordinator.pendingURLs.isEmpty)
        XCTAssertTrue(coordinator.logs.contains { $0.contains("任务已停止") })
    }

    func testCannotStartWithEmptyURLList() {
        let coordinator = DownloadTaskCoordinator(engine: makeEngine(executor: BlockingProcessExecutor()))
        coordinator.start(request: makeRequest(urls: []))
        XCTAssertEqual(coordinator.status, .idle)
    }
}

final class BlockingProcessExecutor: ProcessExecuting {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<ProcessExecutionResult, Never>?
    private var cancelled = false

    func run(executable: URL, arguments: [String], onLine: @escaping (String) -> Void) async -> ProcessExecutionResult {
        await withCheckedContinuation { continuation in
            lock.lock()
            if cancelled {
                lock.unlock()
                continuation.resume(returning: ProcessExecutionResult(exitCode: 143, lines: ["cancelled"]))
            } else {
                self.continuation = continuation
                lock.unlock()
            }
        }
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(returning: ProcessExecutionResult(exitCode: 143, lines: ["cancelled"]))
    }
}

func makeEngine(executor: ProcessExecuting) -> DownloadEngine {
    DownloadEngine(
        tools: ToolLocations(ytDlp: URL(fileURLWithPath: "/usr/bin/true"), ffmpeg: nil),
        executor: executor,
        translator: IdentityTitleTranslator(),
        thumbnailService: RejectingThumbnailService()
    )
}

func makeRequest(urls: [URL]) -> DownloadRequest {
    DownloadRequest(
        sourceURLs: urls,
        settings: .defaults,
        credentials: DownloadCredentials(),
        selectedPages: nil
    )
}

struct RejectingThumbnailService: ThumbnailDownloading {
    func download(from sourceURL: URL, beside videoURL: URL) async throws -> URL {
        throw URLError(.cancelled)
    }
}
