import Foundation

enum SiteLinkKind: Equatable {
    case singleVideo
    case playlist
    case channel

    var isCollection: Bool { self != .singleVideo }
}

enum YtDlpPhase {
    case metadata
    case collection
    case download
}

struct SiteCollectionSource: Equatable {
    let url: URL
    let page: Int?
    let label: String
}

protocol SiteAdapter {
    var siteID: SiteID? { get }
    var displayName: String { get }

    func matches(_ url: URL) -> Bool
    func classify(_ url: URL) -> SiteLinkKind
    func collectionSources(for url: URL, request: DownloadRequest) -> [SiteCollectionSource]
    func collectionArguments(for url: URL, request: DownloadRequest) -> [String]
    func networkArguments(for phase: YtDlpPhase, request: DownloadRequest) -> [String]
    func downloadArguments(for request: DownloadRequest) -> [String]
    func resolvedEntryURL(from entry: [String: Any]) -> URL?
}

extension SiteAdapter {
    func collectionSources(for url: URL, request: DownloadRequest) -> [SiteCollectionSource] {
        [SiteCollectionSource(url: url, page: nil, label: classify(url) == .channel ? "频道" : "播放列表")]
    }

    func collectionArguments(for url: URL, request: DownloadRequest) -> [String] { [] }
    func networkArguments(for phase: YtDlpPhase, request: DownloadRequest) -> [String] { [] }
    func downloadArguments(for request: DownloadRequest) -> [String] { [] }

    func resolvedEntryURL(from entry: [String: Any]) -> URL? {
        for key in ["webpage_url", "original_url", "url"] {
            if let value = entry[key] as? String,
               let url = URL(string: value),
               ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                return url
            }
        }
        return nil
    }
}

enum SiteRegistry {
    private static let adapters: [any SiteAdapter] = [
        PornhubAdapter(),
        YouTubeAdapter(),
    ]
    private static let genericAdapter = GenericSiteAdapter()

    static func adapter(for url: URL) -> any SiteAdapter {
        adapters.first(where: { $0.matches(url) }) ?? genericAdapter
    }

    static func detectedSites(in urls: [URL]) -> Set<SiteID> {
        Set(urls.compactMap { adapter(for: $0).siteID })
    }
}

private struct GenericSiteAdapter: SiteAdapter {
    let siteID: SiteID? = nil
    let displayName = "通用站点"

    func matches(_ url: URL) -> Bool { true }
    func classify(_ url: URL) -> SiteLinkKind {
        CollectionURLBuilder.isCollection(url) ? .playlist : .singleVideo
    }
}
