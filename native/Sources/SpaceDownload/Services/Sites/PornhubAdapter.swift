import Foundation

struct PornhubAdapter: SiteAdapter {
    let siteID: SiteID? = .pornhub
    let displayName = "Pornhub"

    func matches(_ url: URL) -> Bool {
        CollectionURLBuilder.isPornhub(url)
    }

    func classify(_ url: URL) -> SiteLinkKind {
        guard CollectionURLBuilder.isCollection(url) else { return .singleVideo }
        return url.path.lowercased().contains("/playlist/") ? .playlist : .channel
    }

    func collectionSources(for url: URL, request: DownloadRequest) -> [SiteCollectionSource] {
        guard let pages = request.selectedPages,
              CollectionURLBuilder.supportsPageSelection(url)
        else {
            return [SiteCollectionSource(url: url, page: nil, label: "列表")]
        }
        return pages.compactMap { page in
            CollectionURLBuilder.pageURL(from: url, page: page).map {
                SiteCollectionSource(url: $0, page: page, label: "第 \(page) 页")
            }
        }
    }

    func networkArguments(for phase: YtDlpPhase, request: DownloadRequest) -> [String] {
        ["--referer", "https://www.pornhub.com/"]
    }
}
