import Foundation

/// Local display choices; never changes SABnzbd's category configuration.
public struct CategoryPreferences: Codable, Equatable, Sendable {
    public var hidden: Set<String>
    public var favorites: [String]
    public init(hidden: Set<String> = [], favorites: [String] = []) {
        self.hidden = hidden
        self.favorites = favorites
    }
    private enum CodingKeys: String, CodingKey { case hidden, favorites }
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        hidden = try values.decodeIfPresent(Set<String>.self, forKey: .hidden) ?? []
        favorites = try values.decodeIfPresent([String].self, forKey: .favorites) ?? []
    }
    public func isFavorite(_ category: String) -> Bool {
        favorites.contains { $0.caseInsensitiveCompare(category) == .orderedSame }
    }
    public mutating func setFavorite(_ enabled: Bool, category: String) {
        favorites.removeAll { $0.caseInsensitiveCompare(category) == .orderedSame }
        if enabled { favorites.append(category) }
    }
    public mutating func moveFavorite(_ category: String, by offset: Int) {
        guard let index = favorites.firstIndex(where: { $0.caseInsensitiveCompare(category) == .orderedSame }),
              favorites.indices.contains(index + offset) else { return }
        favorites.swapAt(index, index + offset)
    }

    public func visible(in categories: [String]) -> [String] {
        let visible = categories.filter { candidate in
            !hidden.contains { $0.caseInsensitiveCompare(candidate) == .orderedSame }
        }
        let pinned = favorites.compactMap { favorite in
            visible.first { $0.caseInsensitiveCompare(favorite) == .orderedSame }
        }
        var seen = Set<String>()
        return (pinned + visible.filter { !isFavorite($0) }).filter { seen.insert($0).inserted }
    }

    public mutating func setVisible(_ visible: Bool, category: String) {
        let matches = hidden.filter { $0.caseInsensitiveCompare(category) == .orderedSame }
        hidden.subtract(matches)
        if !visible { hidden.insert(category) }
    }
}
