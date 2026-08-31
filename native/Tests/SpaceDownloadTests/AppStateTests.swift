import Combine
import Foundation
import XCTest
@testable import SpaceDownload

@MainActor
final class AppStateTests: XCTestCase {
    func testTelegramPublicMessageNeedsNoCookieAndIsDetectedIndependently() {
        let appState = makeAppState()
        appState.linkText = "https://telegram.me/europa_press/613?single"

        XCTAssertEqual(appState.detectedSiteLabel, "Telegram")
        appState.startDownload()

        XCTAssertNil(appState.validationMessage)
        XCTAssertEqual(appState.taskCoordinator.status, .running)
        appState.stopDownload()
    }

    func testTelegramPrivateAndChannelURLsAreRejectedBeforeGenericDownload() {
        for link in ["https://t.me/+invite", "https://t.me/c/123/456", "https://t.me/public_channel"] {
            let appState = makeAppState()
            appState.linkText = link
            appState.startDownload()
            XCTAssertEqual(appState.validationMessage, "Telegram 当前仅支持公开频道的单条消息链接（t.me/频道/消息ID）；私有群、受限频道和整频道不在本阶段范围")
            XCTAssertEqual(appState.taskCoordinator.status, .idle)
        }
    }

    func testInstagramRequiresItsOwnManualCookiesAndDoesNotReuseOtherSites() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let appState = AppState(settingsStore: SettingsStore(fileURL: directory.appendingPathComponent("settings.json")))
        appState.linkText = "https://www.instagram.com/reel/Chunk8-jurw/?igsh=share"
        appState.settingsStore.settings.sites.instagram.useCookies = true
        appState.xCookiesFileURL = URL(fileURLWithPath: "/tmp/x.txt")
        XCTAssertEqual(appState.detectedSiteLabel, "Instagram")
        appState.startDownload()
        XCTAssertEqual(appState.validationMessage, "Instagram 已启用 Cookies，请先选择 cookies.txt")
    }
    func testDouyinRequiresItsOwnManualCookiesAndDoesNotReuseTikTok() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let appState = AppState(settingsStore: SettingsStore(fileURL: directory.appendingPathComponent("settings.json")))
        appState.linkText = "https://www.douyin.com/video/7530000000000000000"
        appState.settingsStore.settings.sites.douyin.useCookies = true
        appState.tiktokCookiesFileURL = URL(fileURLWithPath: "/tmp/tiktok.txt")
        XCTAssertEqual(appState.detectedSiteLabel, "抖音")
        appState.startDownload()
        XCTAssertEqual(appState.validationMessage, "抖音已启用 Cookies，请先选择 cookies.txt")
    }
    func testTikTokRequiresOnlyItsOwnManuallySelectedCookiesFile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let appState = AppState(settingsStore: SettingsStore(fileURL: directory.appendingPathComponent("settings.json")))
        appState.linkText = "https://www.tiktok.com/@scout2015/video/6718335390845095173"
        appState.settingsStore.settings.sites.tiktok.useCookies = true
        appState.xCookiesFileURL = URL(fileURLWithPath: "/tmp/x.txt")
        appState.startDownload()
        XCTAssertEqual(appState.validationMessage, "TikTok 已启用 Cookies，请先选择 cookies.txt")
    }
    func testStartRejectsEmptyInput() {
        let appState = makeAppState()
        appState.startDownload()

        XCTAssertEqual(appState.validationMessage, "请至少输入一个视频链接")
        XCTAssertEqual(appState.taskCoordinator.status, .idle)
    }

    func testStartRejectsInvalidPageSelection() {
        let appState = makeAppState()
        appState.linkText = "https://www.pornhub.com/model/example"
        appState.settingsStore.settings.pageSelection = "3-1"
        appState.startDownload()

        XCTAssertEqual(appState.validationMessage, "无效分页输入：3-1")
        XCTAssertEqual(appState.taskCoordinator.status, .idle)
    }

    func testStartAcceptsMultipleValidLinks() {
        let appState = makeAppState()
        appState.linkText = "https://example.com/1\nhttps://example.com/2"
        appState.startDownload()

        XCTAssertNil(appState.validationMessage)
        XCTAssertEqual(appState.taskCoordinator.status, .running)
        XCTAssertEqual(appState.taskCoordinator.pendingURLs.count, 2)
        appState.stopDownload()
    }

    func testStartRequiresSelectedCookiesFileWhenEnabled() {
        let appState = makeAppState()
        appState.linkText = "https://www.pornhub.com/view_video.php?viewkey=abc"
        appState.settingsStore.settings.useCookies = true

        appState.startDownload()

        XCTAssertEqual(appState.validationMessage, "Pornhub 已启用 Cookies，请先选择 cookies.txt")
        XCTAssertEqual(appState.taskCoordinator.status, .idle)
    }

    func testYouTubeSettingsAreDetectedAndValidatedIndependently() {
        let appState = makeAppState()
        appState.linkText = "https://www.youtube.com/playlist?list=PL123"
        appState.settingsStore.settings.sites.youtube.playlistSelection = "4-2"

        XCTAssertEqual(appState.detectedSiteLabel, "YouTube")

        appState.startDownload()

        XCTAssertEqual(appState.validationMessage, "YouTube 播放列表序号无效：无效分页输入：4-2")
        XCTAssertEqual(appState.taskCoordinator.status, .idle)
    }

    func testYouTubeCookiesDoNotReusePornhubCookies() {
        let appState = makeAppState()
        appState.linkText = "https://youtu.be/dQw4w9WgXcQ"
        appState.settingsStore.settings.sites.youtube.useCookies = true
        appState.cookiesFileURL = URL(fileURLWithPath: "/tmp/pornhub-cookies.txt")

        appState.startDownload()

        XCTAssertEqual(appState.validationMessage, "YouTube 已启用 Cookies，请先选择 cookies.txt")
        XCTAssertEqual(appState.taskCoordinator.status, .idle)
    }

    func testXCookiesAreDetectedAndDoNotReuseOtherSiteFiles() {
        let appState = makeAppState()
        appState.linkText = "https://x.com/example/status/1234567890"
        appState.settingsStore.settings.sites.x.useCookies = true
        appState.cookiesFileURL = URL(fileURLWithPath: "/tmp/pornhub-cookies.txt")
        appState.youtubeCookiesFileURL = URL(fileURLWithPath: "/tmp/youtube-cookies.txt")

        XCTAssertEqual(appState.detectedSiteLabel, "X")
        appState.startDownload()

        XCTAssertEqual(appState.validationMessage, "X 已启用 Cookies，请先选择 cookies.txt")
        XCTAssertEqual(appState.taskCoordinator.status, .idle)
    }

    func testYouTubeChannelIgnoresSavedPlaylistSelection() {
        let appState = makeAppState()
        appState.linkText = "https://www.youtube.com/@creator/videos"
        appState.settingsStore.settings.sites.youtube.playlistSelection = "4-2"

        appState.startDownload()

        XCTAssertNil(appState.validationMessage)
        XCTAssertEqual(appState.taskCoordinator.status, .running)
        appState.stopDownload()
    }

    func testDownloadProgressAndLogsTriggerFrontendRefresh() async throws {
        let executor = ScriptedProcessExecutor(results: [
            ProcessExecutionResult(exitCode: 0, lines: [#"{"id":"abc","title":"Video"}"#]),
            ProcessExecutionResult(exitCode: 0, lines: [
                "[download] Destination: /tmp/video.mp4",
                "SPACEDOWNLOAD_PROGRESS:50%|1MiB/s|00:05",
                #"SPACEDOWNLOAD_RESULT:{"filepath":"/tmp/video.mp4"}"#,
            ]),
        ])
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("settings.json")
        let appState = AppState(
            settingsStore: SettingsStore(fileURL: fileURL),
            taskCoordinator: DownloadTaskCoordinator(engine: makeEngine(executor: executor))
        )
        appState.settingsStore.settings.translateTitle = false
        appState.settingsStore.settings.embedThumbnail = false
        appState.linkText = "https://example.com/video"
        var refreshCount = 0
        let cancellable = appState.objectWillChange.sink {
            refreshCount += 1
        }

        appState.startDownload()
        for _ in 0..<100 where appState.taskCoordinator.status.isActive {
            try await Task.sleep(for: .milliseconds(10))
        }

        XCTAssertGreaterThan(refreshCount, 5)
        XCTAssertEqual(appState.taskCoordinator.progress, 1)
        XCTAssertFalse(appState.taskCoordinator.logs.contains { $0.contains("[下载进度]") })
        withExtendedLifetime(cancellable) {}
    }

    private func makeAppState() -> AppState {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("settings.json")
        return AppState(
            settingsStore: SettingsStore(fileURL: fileURL),
            taskCoordinator: DownloadTaskCoordinator(engine: makeEngine(executor: BlockingProcessExecutor()))
        )
    }
}
