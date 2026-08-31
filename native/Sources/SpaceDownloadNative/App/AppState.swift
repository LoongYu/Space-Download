import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class AppState: ObservableObject {
    @Published var linkText = ""
    @Published var isSettingsVisible = true
    @Published var validationMessage: String?
    @Published var password = ""
    @Published var cookiesFileURL: URL?

    let settingsStore: SettingsStore
    let taskCoordinator: DownloadTaskCoordinator

    init(
        settingsStore: SettingsStore? = nil,
        taskCoordinator: DownloadTaskCoordinator? = nil
    ) {
        self.settingsStore = settingsStore ?? SettingsStore()
        self.taskCoordinator = taskCoordinator ?? DownloadTaskCoordinator()
    }

    var parsedLinks: [URL] {
        LinkParser.parse(linkText).validURLs
    }

    func chooseDownloadDirectory() {
        let panel = NSOpenPanel()
        panel.title = "选择保存目录"
        panel.prompt = "选择"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = URL(fileURLWithPath: settingsStore.settings.downloadPath)

        guard panel.runModal() == .OK, let selectedURL = panel.url else { return }
        settingsStore.settings.downloadPath = selectedURL.path
    }

    func chooseCookiesFile() {
        let panel = NSOpenPanel()
        panel.title = "选择 cookies.txt"
        panel.prompt = "选择"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.plainText]
        guard panel.runModal() == .OK else { return }
        cookiesFileURL = panel.url
    }

    func startDownload() {
        let result = LinkParser.parse(linkText)
        guard result.invalidEntries.isEmpty else {
            validationMessage = "以下内容不是有效链接：\(result.invalidEntries.joined(separator: "，"))"
            return
        }
        guard !result.validURLs.isEmpty else {
            validationMessage = "请至少输入一个视频链接"
            return
        }
        if settingsStore.settings.useCookies, cookiesFileURL == nil {
            validationMessage = "已启用 Cookies，请先选择 cookies.txt"
            return
        }

        let selectedPages: [Int]?
        do {
            selectedPages = try PageSelectionParser.parse(settingsStore.settings.pageSelection)
        } catch {
            validationMessage = error.localizedDescription
            return
        }

        validationMessage = nil
        taskCoordinator.start(request: DownloadRequest(
            sourceURLs: result.validURLs,
            settings: settingsStore.settings,
            credentials: DownloadCredentials(password: password, cookiesFileURL: cookiesFileURL),
            selectedPages: selectedPages
        ))
    }

    func stopDownload() {
        taskCoordinator.stop()
    }
}
