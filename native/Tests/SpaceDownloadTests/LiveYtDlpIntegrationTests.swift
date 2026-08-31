import Combine
import Foundation
import XCTest
@testable import SpaceDownload

final class LiveYtDlpIntegrationTests: XCTestCase {
    func testDownloadsLocalMediaWithRealYtDlp() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let mediaURLText = environment["SPACEDOWNLOAD_LOCAL_MEDIA_URL"],
              let mediaURL = URL(string: mediaURLText),
              let outputPath = environment["SPACEDOWNLOAD_INTEGRATION_OUTPUT"]
        else {
            throw XCTSkip("Set local integration environment variables to run")
        }
        let tools = try XCTUnwrap(YtDlpLocator.locate())
        var settings = DownloadSettings.defaults
        settings.downloadPath = outputPath
        settings.filenameTemplate = .title
        settings.translateTitle = false
        settings.embedThumbnail = false
        settings.outputFormat = .mp4
        let engine = DownloadEngine(
            tools: tools,
            translator: IdentityTitleTranslator(),
            thumbnailService: RejectingThumbnailService()
        )
        engine.prepareForExecution()

        let summary = await engine.execute(
            request: DownloadRequest(
                sourceURLs: [mediaURL],
                settings: settings,
                credentials: .init(),
                selectedPages: nil
            ),
            onEvent: { _ in }
        )

        XCTAssertEqual(summary.completed, 1)
        XCTAssertTrue(summary.failures.isEmpty)
        let files = try FileManager.default.contentsOfDirectory(atPath: outputPath)
        XCTAssertTrue(files.contains { $0.hasSuffix(".mp4") })
    }

    @MainActor
    func testCoordinatorStartsRealRemoteDownload() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let urlText = environment["SPACEDOWNLOAD_LIVE_URL"],
              let url = URL(string: urlText)
        else {
            throw XCTSkip("Set SPACEDOWNLOAD_LIVE_URL to run")
        }

        let outputDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpaceDownload-Live-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outputDirectory) }

        let tools = try XCTUnwrap(YtDlpLocator.locate())
        var settings = DownloadSettings.defaults
        settings.downloadPath = outputDirectory.path
        settings.quality = .standard
        settings.translateTitle = false
        settings.embedThumbnail = false
        let coordinator = DownloadTaskCoordinator(engine: DownloadEngine(
            tools: tools,
            translator: IdentityTitleTranslator(),
            thumbnailService: RejectingThumbnailService(),
            metadataLogger: MetadataDebugLogger(directoryURL: outputDirectory.appendingPathComponent("logs"))
        ))
        let appState = AppState(
            settingsStore: SettingsStore(fileURL: outputDirectory.appendingPathComponent("settings.json")),
            taskCoordinator: coordinator
        )
        appState.settingsStore.settings = settings
        appState.linkText = url.absoluteString
        var frontendRefreshCount = 0
        let cancellable = appState.objectWillChange.sink {
            frontendRefreshCount += 1
        }

        appState.startDownload()

        for _ in 0..<1_200 where coordinator.progress == 0 && coordinator.status.isActive {
            try await Task.sleep(for: .milliseconds(50))
        }
        let observedProgress = coordinator.progress
        if coordinator.status == .running {
            coordinator.stop()
        }
        for _ in 0..<200 where coordinator.status.isActive {
            try await Task.sleep(for: .milliseconds(10))
        }

        XCTAssertGreaterThan(observedProgress, 0)
        XCTAssertTrue(coordinator.status == .idle || coordinator.status == .completed)
        XCTAssertTrue(coordinator.logs.contains { $0.contains("视频信息") })
        XCTAssertFalse(coordinator.logs.contains { $0.contains("\"formats\"") })
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: outputDirectory.appendingPathComponent("logs/metadata.log").path
        ))
        XCTAssertFalse(coordinator.logs.contains { $0.contains("[下载进度]") })
        XCTAssertGreaterThan(frontendRefreshCount, 5)
        withExtendedLifetime(cancellable) {}
    }
}
