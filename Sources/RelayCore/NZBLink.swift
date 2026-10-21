import Foundation

/// NZBlnk URI data. Protocol source: https://nzblnk.info/
public struct NZBLink: Equatable, Sendable, Identifiable {
    public let id = UUID()
    public let header: String
    public let title: String
    public let password: String?
    public let groups: [String]

    public init(_ raw: String) throws {
        let input = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard input.utf8.count <= 32_768,
              let uri = URLComponents(string: input),
              uri.scheme?.caseInsensitiveCompare("nzblnk") == .orderedSame,
              uri.host == nil || uri.host == "",
              uri.path.isEmpty, uri.fragment == nil,
              let query = uri.percentEncodedQuery else {
            throw RelayError.message("The link must be an NZBlnk address with a search identifier.")
        }
        var parameters = [String: [String]]()
        for field in query.split(separator: "&") {
            let pair = field.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            func decode(_ part: Substring) throws -> String {
                guard let text = String(part).replacingOccurrences(of: "+", with: " ").removingPercentEncoding else {
                    throw RelayError.message("The NZBlnk link contains invalid character encoding.")
                }
                return text
            }
            let name = try decode(pair[0])
            let value = try decode(pair.count == 2 ? pair[1] : "")
            parameters[name, default: []].append(value)
        }
        func single(_ name: String) throws -> String? {
            let values = parameters[name] ?? []
            guard Set(values).count <= 1 else {
                throw RelayError.message("The NZBlnk link contains conflicting values for \(name).")
            }
            return values.first.flatMap { $0.isEmpty ? nil : $0 }
        }
        guard let search = try single("h"), !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RelayError.message("The NZBlnk link is missing the search identifier (h).")
        }
        header = search
        // Compatibility with existing links that omit the specification's title.
        title = try single("t") ?? search
        password = try single("p")
        groups = (parameters["g"] ?? []).filter { !$0.isEmpty }
    }
}
