import Foundation

enum CollectionURLBuilder {
    private static let collectionMarkers = [
        "/playlist/", "/model/", "/models/", "/channels/", "/channel/",
        "/users/", "/user/", "/pornstar/", "/pornstars/",
    ]
    private static let profileMarkers = [
        "/model/", "/models/", "/channels/", "/channel/",
        "/users/", "/user/", "/pornstar/", "/pornstars/",
    ]

    static func isCollection(_ url: URL) -> Bool {
        let value = url.absoluteString.lowercased()
        return collectionMarkers.contains { value.contains($0) }
    }

    static func isPornhub(_ url: URL) -> Bool {
        url.host?.lowercased().contains("pornhub") == true
    }

    static func supportsPageSelection(_ url: URL) -> Bool {
        isPornhub(url) && isCollection(url) && !url.path.lowercased().contains("/playlist/")
    }

    static func pageURL(from url: URL, page: Int) -> URL? {
        guard page > 0, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        var path = components.path
        let lowercasedPath = path.lowercased()
        if profileMarkers.contains(where: { lowercasedPath.hasPrefix($0) })
            && !lowercasedPath.contains("/videos") {
            path = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            components.path = "/\(path)/videos"
        }

        var queryItems = components.queryItems ?? []
        queryItems.removeAll { $0.name == "page" }
        queryItems.append(URLQueryItem(name: "page", value: String(page)))
        components.queryItems = queryItems
        return components.url
    }
}
