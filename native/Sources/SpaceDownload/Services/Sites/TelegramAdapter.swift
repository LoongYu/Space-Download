import Foundation

struct TelegramAdapter: SiteAdapter {
    let siteID: SiteID? = .telegram
    let displayName = "Telegram"
    let expandsMediaResources = true

    func matches(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased(),
              ["t.me", "www.t.me", "telegram.me", "www.telegram.me"].contains(host)
        else { return false }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count == 2,
              parts[0].range(of: #"^[A-Za-z0-9_]+$"#, options: .regularExpression) != nil,
              !parts[0].hasPrefix("_"),
              !["c", "joinchat", "addstickers", "share", "proxy", "socks", "iv", "login"].contains(parts[0].lowercased())
        else { return false }
        return parts[1].first != "0" && parts[1].allSatisfy(\.isNumber)
    }

    func classify(_ url: URL) -> SiteLinkKind { .singleVideo }

    /// Removing all share parameters is intentional: yt-dlp interprets the
    /// blank `single` query as a request to suppress the rest of a media group.
    func canonicalURL(_ url: URL) -> URL {
        guard matches(url), var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        components.scheme = "https"
        components.host = "t.me"
        components.port = nil
        components.query = nil
        components.fragment = nil
        if components.path.hasSuffix("/") { components.path.removeLast() }
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
                stableID: telegramStableID(entryID: id, sourceURL: sourceURL),
                kind: socialMediaResourceKind(from: entry),
                selector: entries == nil ? nil : selector,
                metadataJSON: data
            )
        }
    }

    private func telegramStableID(entryID: String, sourceURL: URL) -> String {
        let parts = canonicalURL(sourceURL).pathComponents.filter { $0 != "/" }
        guard parts.count == 2 else { return entryID }
        return "\(parts[0])-\(entryID)"
    }
}
