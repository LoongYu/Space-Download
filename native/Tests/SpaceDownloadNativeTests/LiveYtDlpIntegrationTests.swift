import Foundation
import XCTest
@testable import SpaceDownloadNative

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
}
