import Foundation

public struct IndexerPreferences: Codable, Equatable, Sendable {
    public enum Indexer: String, CaseIterable, Identifiable, Sendable {
        case nzbIndex = "NZBIndex"
        case nzbKing = "NZBKing"
        case binSearch = "BinSearch"
        case treasureMaps = "Treasure Maps"
        case newzBay = "NewzBay"
        case ninjaCentral = "NinjaCentral"
        case drunkenSlug = "DrunkenSlug"
        case nzbFinder = "NZBFinder"
        case videothek = "Videothek.io"
        case easynews = "Easynews"

        public var id: Self { self }
    }

    public private(set) var order = Indexer.allCases
    public private(set) var disabled: Set<Indexer> = []

    public init() {}

    public mutating func setEnabled(_ enabled: Bool, for indexer: Indexer) {
        if enabled { disabled.remove(indexer) }
        else { disabled.insert(indexer) }
    }

    public mutating func move(_ indexer: Indexer, by offset: Int) {
        guard let index = order.firstIndex(of: indexer), order.indices.contains(index + offset) else { return }
        order.swapAt(index, index + offset)
    }

    private enum CodingKeys: String, CodingKey { case order, disabled }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let savedOrder = try values.decodeIfPresent([String].self, forKey: .order) ?? []
        var seen = Set<Indexer>()
        order = (savedOrder.compactMap(Indexer.init(rawValue:)) + Indexer.allCases)
            .filter { seen.insert($0).inserted }
        let savedDisabled = try values.decodeIfPresent([String].self, forKey: .disabled) ?? []
        disabled = Set(savedDisabled.compactMap(Indexer.init(rawValue:)))
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(order.map(\.rawValue), forKey: .order)
        try values.encode(order.filter(disabled.contains).map(\.rawValue), forKey: .disabled)
    }
}
