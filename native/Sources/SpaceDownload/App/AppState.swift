import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
final class AppState: ObservableObject {
    @Published var linkText = ""
    @Published var validationMessage: String?
    @Published var password = ""
    @Published var cookiesFileURL: URL?
    @Published var youtubeCookiesFileURL: URL?
    @Published var xCookiesFileURL: URL?
    @Published var tiktokCookiesFileURL: URL?
    @Published var douyinCookiesFileURL: URL?
    @Published var instagramCookiesFileURL: URL?

    let settingsStore: SettingsStore
    let taskCoordinator: DownloadTaskCoordinator
    private var cancellables = Set<AnyCancellable>()

    init(
        settingsStore: SettingsStore? = nil,
        taskCoordinator: DownloadTaskCoordinator? = nil
    ) {
        self.settingsStore = settingsStore ?? SettingsStore()
        self.taskCoordinator = taskCoordinator ?? DownloadTaskCoordinator()

        self.taskCoordinator.objectWillChange
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    var parsedLinks: [URL] {
        LinkParser.parse(linkText).validURLs
    }

    var detectedSiteLabel: String {
        let sites = SiteRegistry.detectedSites(in: parsedLinks)
        if sites.isEmpty { return "等待识别站点" }
        if sites.count > 1 { return "混合站点任务" }
        return sites.first?.displayName ?? "通用站点"
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

    func chooseCookiesFile(for siteID: SiteID) {
        let panel = NSOpenPanel()
        panel.title = "选择 cookies.txt"
        panel.prompt = "选择"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.plainText]
        guard panel.runModal() == .OK else { return }
        switch siteID {
        case .pornhub: cookiesFileURL = panel.url
        case .youtube: youtubeCookiesFileURL = panel.url
        case .x: xCookiesFileURL = panel.url
        case .tiktok: tiktokCookiesFileURL = panel.url
        case .douyin: douyinCookiesFileURL = panel.url
        case .instagram: instagramCookiesFileURL = panel.url
        case .telegram: return
        }
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
        if result.validURLs.contains(where: { url in
            guard let host = url.host?.lowercased() else { return false }
            let isTelegramHost = ["t.me", "www.t.me", "telegram.me", "www.telegram.me"].contains(host)
            return isTelegramHost && SiteRegistry.adapter(for: url).siteID != .telegram
        }) {
            validationMessage = "Telegram 当前仅支持公开频道的单条消息链接（t.me/频道/消息ID）；私有群、受限频道和整频道不在本阶段范围"
            return
        }
        let detectedSites = SiteRegistry.detectedSites(in: result.validURLs)
        if detectedSites.contains(.pornhub),
           settingsStore.settings.sites.pornhub.useCookies,
           cookiesFileURL == nil {
            validationMessage = "Pornhub 已启用 Cookies，请先选择 cookies.txt"
            return
        }
        if detectedSites.contains(.youtube),
           settingsStore.settings.sites.youtube.useCookies,
           youtubeCookiesFileURL == nil {
            validationMessage = "YouTube 已启用 Cookies，请先选择 cookies.txt"
            return
        }
        if detectedSites.contains(.x),
           settingsStore.settings.sites.x.useCookies,
           xCookiesFileURL == nil {
            validationMessage = "X 已启用 Cookies，请先选择 cookies.txt"
            return
        }
        if detectedSites.contains(.tiktok),
           settingsStore.settings.sites.tiktok.useCookies,
           tiktokCookiesFileURL == nil {
            validationMessage = "TikTok 已启用 Cookies，请先选择 cookies.txt"
            return
        }
        if detectedSites.contains(.douyin),
           settingsStore.settings.sites.douyin.useCookies,
           douyinCookiesFileURL == nil {
            validationMessage = "抖音已启用 Cookies，请先选择 cookies.txt"
            return
        }
        if detectedSites.contains(.instagram),
           settingsStore.settings.sites.instagram.useCookies,
           instagramCookiesFileURL == nil {
            validationMessage = "Instagram 已启用 Cookies，请先选择 cookies.txt"
            return
        }

        let selectedPages: [Int]?
        if detectedSites.contains(.pornhub) {
            do {
                selectedPages = try PageSelectionParser.parse(settingsStore.settings.pageSelection)
            } catch {
                validationMessage = error.localizedDescription
                return
            }
        } else {
            selectedPages = nil
        }

        let hasYouTubePlaylist = result.validURLs.contains {
            let adapter = SiteRegistry.adapter(for: $0)
            return adapter.siteID == .youtube && adapter.classify($0) == .playlist
        }
        let youtubePlaylistItems: [Int]?
        if hasYouTubePlaylist {
            do {
                youtubePlaylistItems = try PageSelectionParser.parse(
                    settingsStore.settings.sites.youtube.playlistSelection
                )
            } catch {
                validationMessage = "YouTube 播放列表序号无效：\(error.localizedDescription)"
                return
            }
        } else {
            youtubePlaylistItems = nil
        }

        validationMessage = nil
        taskCoordinator.start(request: DownloadRequest(
            sourceURLs: result.validURLs,
            settings: settingsStore.settings,
            credentials: DownloadCredentials(
                password: password,
                cookiesFileURL: cookiesFileURL,
                youtubeCookiesFileURL: youtubeCookiesFileURL,
                xCookiesFileURL: xCookiesFileURL,
                tiktokCookiesFileURL: tiktokCookiesFileURL,
                douyinCookiesFileURL: douyinCookiesFileURL,
                instagramCookiesFileURL: instagramCookiesFileURL
            ),
            selectedPages: selectedPages,
            youtubePlaylistItems: youtubePlaylistItems
        ))
    }

    func stopDownload() {
        taskCoordinator.stop()
    }
}
