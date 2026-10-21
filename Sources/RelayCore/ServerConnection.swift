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
            throw RelayError.message("Enter the SABnzbd HTTP or HTTPS address without credentials or URL parameters.")
        }
        let segments = url.path.split(separator: "/").map(String.init)
        url.path = "/" + (segments.last == "api" ? segments : segments + ["api"]).joined(separator: "/")
        guard let endpoint = url.url else { throw RelayError.message("The SABnzbd address is invalid.") }
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw RelayError.message("Enter the complete SABnzbd API key.") }
        self.endpoint = endpoint
        self.apiKey = key
    }
}
