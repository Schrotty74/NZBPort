import Foundation

public enum IndexerConnectionTest {
    public static func run(_ indexer: IndexerPreferences.Indexer, link input: String, apiKey: String = "",
                           username: String = "", password: String = "",
                           transport: (any HTTPTransport)? = nil) async throws {
        let input = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if input.isEmpty, indexer != .easynews {
            throw RelayError.message("Enter an NZBlnk that this search service can find.")
        }
        let link = try NZBLink(input.isEmpty ? "nzblnk:?h=TEST&t=TEST" : input)

        var preferences = IndexerPreferences()
        for other in preferences.order where other != indexer {
            preferences.setEnabled(false, for: other)
        }

        var newznabClients: [NewznabClient] = []
        var easynews: EasynewsClient?
        if indexer == .easynews {
            guard let client = EasynewsClient(username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                                               password: password, transport: transport) else {
                throw RelayError.message("Enter a valid Easynews username and password.")
            }
            easynews = client
        } else if let service = NewznabClient.Service.allCases.first(where: { $0.indexer == indexer }) {
            let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { throw RelayError.message("The search service requires an API key.") }
            newznabClients.append(NewznabClient(apiKey: key, service: service, transport: transport))
        }

        let resolver = NZBResolver(transport: transport ?? SessionTransport(), newznabClients: newznabClients,
                                   preferences: preferences, easynews: easynews)
        _ = try await resolver.fileForExport(link)
    }
}
