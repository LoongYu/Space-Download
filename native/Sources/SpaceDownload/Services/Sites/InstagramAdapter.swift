import Foundation

struct InstagramAdapter: SiteAdapter {
    let siteID: SiteID? = .instagram
    let displayName = "Instagram"
    let expandsMediaResources = true

    func matches(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased(),
              host == "instagram.com" || host == "www.instagram.com" || host == "m.instagram.com"
        else { return false }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count == 2, ["reel", "p", "tv"].contains(parts[0].lowercased()) else { return false }
        return parts[1].range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil
    }

    func classify(_ url: URL) -> SiteLinkKind { .singleVideo }

    func canonicalURL(_ url: URL) -> URL {
        guard matches(url), var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        components.scheme = "https"
        components.host = "www.instagram.com"
        components.query = nil
        components.fragment = nil
        if !components.path.hasSuffix("/") { components.path += "/" }
        return components.url ?? url
    }

    func mediaResources(from metadata: [String: Any], sourceURL: URL) -> [MediaResourceTask] {
        let entries = metadata["entries"] as? [[String: Any]]
        let candidates = entries?.enumerated().map { ($0.offset + 1, $0.element) } ?? [(1, metadata)]
        return candidates.compactMap { selector, entry in
            guard let id = entry["id"] as? String, !id.isEmpty,
                  let data = try? JSONSerialization.data(withJSONObject: entry, options: [.sortedKeys])
            else { return nil }
            return MediaResourceTask(
                stableID: id,
                kind: socialMediaResourceKind(from: entry),
                selector: entries == nil ? nil : selector,
                metadataJSON: data
            )
        }
    }

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
