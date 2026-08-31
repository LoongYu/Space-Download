import Foundation
import XCTest
@testable import SpaceDownloadNative

@MainActor
final class AppStateTests: XCTestCase {
    func testStartRejectsEmptyInput() {
        let appState = makeAppState()
        appState.startDownload()

        XCTAssertEqual(appState.validationMessage, "请至少输入一个视频链接")
        XCTAssertEqual(appState.taskCoordinator.status, .idle)
    }

    func testStartRejectsInvalidPageSelection() {
        let appState = makeAppState()
        appState.linkText = "https://example.com/video"
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
        appState.linkText = "https://example.com/video"
        appState.settingsStore.settings.useCookies = true

        appState.startDownload()

        XCTAssertEqual(appState.validationMessage, "已启用 Cookies，请先选择 cookies.txt")
        XCTAssertEqual(appState.taskCoordinator.status, .idle)
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
