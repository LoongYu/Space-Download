import Foundation

enum PageSelectionError: LocalizedError, Equatable {
    case invalidToken(String)

    var errorDescription: String? {
        switch self {
        case let .invalidToken(token):
            return "无效分页输入：\(token)"
        }
    }
}

enum PageSelectionParser {
    static func parse(_ text: String) throws -> [Int]? {
        let selection = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selection.isEmpty else { return nil }

        var pages = Set<Int>()
        for rawToken in selection.split(separator: ",", omittingEmptySubsequences: false) {
            let token = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !token.isEmpty else { continue }

            if token.contains("-") {
                let bounds = token.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
                guard bounds.count == 2,
                      let start = Int(bounds[0].trimmingCharacters(in: .whitespaces)),
                      let end = Int(bounds[1].trimmingCharacters(in: .whitespaces)),
                      start > 0,
                      end >= start
                else {
                    throw PageSelectionError.invalidToken(token)
                }
                pages.formUnion(start...end)
            } else {
                guard let page = Int(token), page > 0 else {
                    throw PageSelectionError.invalidToken(token)
                }
                pages.insert(page)
            }
        }

        return pages.sorted()
    }
}
