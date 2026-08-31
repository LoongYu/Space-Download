import Foundation

struct DownloadCredentials: Equatable {
    var password = ""
    var cookiesFileURL: URL?
}

struct DownloadRequest: Equatable {
    let sourceURLs: [URL]
    let settings: DownloadSettings
    let credentials: DownloadCredentials
    let selectedPages: [Int]?
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
