import Foundation

struct XAdapter: SiteAdapter {
    let siteID: SiteID? = .x
    let displayName = "X"
    let expandsMediaResources = true

    func matches(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased(), host == "x.com" || host == "www.x.com"
                || host == "twitter.com" || host == "www.twitter.com" || host == "mobile.twitter.com"
        else { return false }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard let statusIndex = parts.firstIndex(of: "status"), statusIndex + 1 < parts.count else { return false }
        return parts[statusIndex + 1].allSatisfy(\.isNumber)
    }

    func classify(_ url: URL) -> SiteLinkKind { .singleVideo }

    func mediaResources(from metadata: [String: Any], sourceURL: URL) -> [MediaResourceTask] {
        let entries = metadata["entries"] as? [[String: Any]]
        let candidates = entries?.enumerated().map { ($0.offset + 1, $0.element) } ?? [(1, metadata)]
        return candidates.compactMap { selector, entry in
            guard let id = entry["id"] as? String, !id.isEmpty,
                  let data = try? JSONSerialization.data(withJSONObject: entry, options: [.sortedKeys])
            else { return nil }
            let kind = socialMediaResourceKind(from: entry)
            return MediaResourceTask(
                stableID: id,
                kind: kind,
                selector: entries == nil ? nil : selector,
                metadataJSON: data
            )
        }
    }

}

func socialMediaResourceKind(from metadata: [String: Any]) -> MediaResourceTask.Kind {
    let extensionName = (metadata["ext"] as? String)?.lowercased()
    let format = (metadata["format"] as? String)?.lowercased() ?? ""
    if extensionName == "gif" || format.contains("gif") || metadata["is_animated"] as? Bool == true {
        return .animatedGIF
    }
    if ["jpg", "jpeg", "png", "webp", "avif"].contains(extensionName ?? "") {
        return .image
    }
    return .video
}
