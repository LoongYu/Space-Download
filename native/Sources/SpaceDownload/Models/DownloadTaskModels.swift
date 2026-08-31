import Foundation

struct DownloadCredentials: Equatable {
    var password = ""
    var cookiesFileURL: URL?
    var youtubeCookiesFileURL: URL?

    func cookiesFileURL(for siteID: SiteID?) -> URL? {
        switch siteID {
        case .youtube: youtubeCookiesFileURL
        case .pornhub, .none: cookiesFileURL
        }
    }
}

struct DownloadRequest: Equatable {
    let sourceURLs: [URL]
    let settings: DownloadSettings
    let credentials: DownloadCredentials
    let selectedPages: [Int]?
    let youtubePlaylistItems: [Int]?

    init(
        sourceURLs: [URL],
        settings: DownloadSettings,
        credentials: DownloadCredentials,
        selectedPages: [Int]?,
        youtubePlaylistItems: [Int]? = nil
    ) {
        self.sourceURLs = sourceURLs
        self.settings = settings
        self.credentials = credentials
        self.selectedPages = selectedPages
        self.youtubePlaylistItems = youtubePlaylistItems
    }
}

struct DownloadItem: Equatable {
    let url: URL
    let title: String
    let page: Int?
    let pageIndex: Int?
}

struct DownloadFailure: Equatable, Identifiable {
    let id = UUID()
    let title: String
    let url: URL
    let reason: String

    static func == (lhs: DownloadFailure, rhs: DownloadFailure) -> Bool {
        lhs.title == rhs.title && lhs.url == rhs.url && lhs.reason == rhs.reason
    }
}

struct DownloadSummary: Equatable {
    var completed = 0
    var failures: [DownloadFailure] = []
    var wasCancelled = false
}

enum DownloadEngineEvent: Equatable {
    case log(String)
    case prepared(total: Int)
    case itemStarted(index: Int, total: Int, title: String, url: URL)
    case itemProgress(Double, speed: String, eta: String)
    case itemSkipped(title: String, url: URL, existingFile: URL)
    case itemSucceeded(title: String, url: URL)
    case itemFailed(DownloadFailure)
}
