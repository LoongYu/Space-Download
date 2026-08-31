import Foundation

struct DouyinAdapter: SiteAdapter {
    let siteID: SiteID? = .douyin
    let displayName = "抖音"

    func matches(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        if host == "v.douyin.com" { return !url.path.isEmpty && url.path != "/" }
        guard host == "douyin.com" || host == "www.douyin.com" else { return false }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count == 2, parts[0] == "video" else { return false }
        return parts[1].allSatisfy(\.isNumber)
    }

    func classify(_ url: URL) -> SiteLinkKind { .singleVideo }

    func preferredThumbnail(from metadata: [String: Any]) -> SiteThumbnail? {
        let baseHeaders = stringHeaders(from: metadata["http_headers"])
        let candidates = (metadata["thumbnails"] as? [[String: Any]] ?? []).compactMap { entry -> SiteThumbnail? in
            guard let value = entry["url"] as? String, let url = URL(string: value) else { return nil }
            return SiteThumbnail(
                url: url,
                headers: baseHeaders.merging(stringHeaders(from: entry["http_headers"])) { _, new in new },
                width: (entry["width"] as? NSNumber)?.intValue,
                height: (entry["height"] as? NSNumber)?.intValue
            )
        }
        return candidates.max { lhs, rhs in
            (lhs.width ?? 0) * (lhs.height ?? 0) < (rhs.width ?? 0) * (rhs.height ?? 0)
        } ?? metadataThumbnail(from: metadata)
    }
}
