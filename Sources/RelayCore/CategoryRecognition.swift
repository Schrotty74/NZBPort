import Foundation

public struct CategoryRecognition: Codable, Equatable, Sendable {
    public enum Kind: String, CaseIterable, Sendable {
        case series, games, movies, misc

        public static func detect(in title: String) -> Self {
            if title.range(of: completePattern, options: [.regularExpression, .caseInsensitive]) != nil { return .series }
            if title.range(of: gamePattern, options: [.regularExpression, .caseInsensitive]) != nil { return .games }
            if title.range(of: seriesPattern, options: [.regularExpression, .caseInsensitive]) != nil { return .series }
            if title.range(of: moviePattern, options: [.regularExpression, .caseInsensitive]) != nil { return .movies }
            return .misc
        }

        // Complete packs take precedence over the original userscript markers.
        private static let completePattern = #"(?:^|[^\p{L}\p{N}])complete(?=$|[^\p{L}\p{N}])"#
        private static let gamePattern = #"(?:^|[^a-z0-9])(?:ps[345]|psvita|xbox(?:[ ._-]+(?:360|one|series[ ._-]*[xs]))?|nintendo[ ._-]+switch|pc[ ._-]+game|fitgirl|dodi[ ._-]+repack|tenoke|skidrow|razor1911|flt|gog|early[ ._-]+access)(?=$|[^a-z0-9])|(?:^|[ ._-])(?:elamigos|tinyhell|rune|doge|voices38)\s*$"#
        private static let seriesPattern = #"(?:^|[^a-z0-9])(?:s[0-9]{1,3}(?:e[0-9]{1,3})*|[0-9]{1,2}x[0-9]{2,3})(?=$|[^a-z0-9])"#
        private static let moviePattern = #"(?:^|[^a-z0-9])(?:blu[ ._-]?ray|b[dr]rip|bdr|web(?:[ ._-]?(?:dl|rip))?|remux|hdtv|dvd[ ._-]?rip|uhd[ ._-]?blu[ ._-]?ray)(?=$|[^a-z0-9])"#
    }

    public struct Rule: Codable, Equatable, Identifiable, Sendable {
        public var id: UUID
        public var pattern: String
        public var category: String?

        public init(pattern: String = "", category: String? = nil) {
            id = UUID()
            self.pattern = pattern
            self.category = category
        }
    }

    private var destinations: [String: String] = [:]
    public var automaticallySends = false
    public var rules: [Rule] = []

    public init() {}

    public subscript(kind: Kind) -> String? {
        get { destinations[kind.rawValue] }
        set { destinations[kind.rawValue] = newValue }
    }

    public func suggestion(for title: String, availableCategories: [String]) -> String? {
        guard !availableCategories.isEmpty, !destinations.isEmpty || !rules.isEmpty else { return nil }
        let available = Set(availableCategories)
        let normalizedTitle = Self.normalize(title)
        for rule in rules {
            guard let category = rule.category, available.contains(category) else { continue }
            let pattern = Self.normalize(rule.pattern)
            if !pattern.isEmpty, normalizedTitle.contains(pattern) { return category }
        }
        return self[Kind.detect(in: title)].flatMap { available.contains($0) ? $0 : nil }
    }

    private static func normalize(_ title: String) -> String {
        title.lowercased()
            .replacingOccurrences(of: #"[._\s]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
