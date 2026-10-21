import Foundation

public struct ServerConnection: Sendable {
    public let endpoint: URL
    public let apiKey: String

    public init(address: String, apiKey: String) throws {
        let address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var url = URLComponents(string: address),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil else {
            throw RelayError.message("Bitte die HTTP- oder HTTPS-Adresse von SABnzbd ohne Zugangsdaten oder URL-Parameter eintragen.")
        }
        let segments = url.path.split(separator: "/").map(String.init)
        url.path = "/" + (segments.last == "api" ? segments : segments + ["api"]).joined(separator: "/")
        guard let endpoint = url.url else { throw RelayError.message("Die SABnzbd-Adresse ist ungültig.") }
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw RelayError.message("Bitte den vollständigen SABnzbd-API-Key eintragen.") }
        self.endpoint = endpoint
        self.apiKey = key
    }
}
