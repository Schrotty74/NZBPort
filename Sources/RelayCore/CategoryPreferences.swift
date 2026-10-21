import Foundation

/// Local display choices; never changes SABnzbd's category configuration.
public struct CategoryPreferences: Codable, Equatable, Sendable {
    public var hidden: Set<String>
    public init(hidden: Set<String> = []) { self.hidden = hidden }

    public func visible(in categories: [String]) -> [String] {
        categories.filter { candidate in
            !hidden.contains { $0.caseInsensitiveCompare(candidate) == .orderedSame }
        }
    }

    public mutating func setVisible(_ visible: Bool, category: String) {
        let matches = hidden.filter { $0.caseInsensitiveCompare(category) == .orderedSame }
        hidden.subtract(matches)
        if !visible { hidden.insert(category) }
    }
}
