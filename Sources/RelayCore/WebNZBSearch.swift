import Foundation

/// Follows the providers' public search forms; no embedded browser or JavaScript.
actor WebNZBSearch: NZBSearchProvider {
    enum Provider: Sendable { case king, binsearch }
    let provider: Provider
    let transport: any HTTPTransport

    nonisolated var name: String { provider == .king ? "NZBKing" : "BinSearch" }

    init(provider: Provider, transport: any HTTPTransport) {
        self.provider = provider
        self.transport = transport
    }

    func resolve(_ link: NZBLink) async throws -> URL {
        let origin = URL(string: provider == .king ? "https://www.nzbking.com/" : "https://www.binsearch.info/")!
        var search = URLComponents(url: provider == .king ? origin : origin.appendingPathComponent("search"), resolvingAgainstBaseURL: false)!
        search.queryItems = [URLQueryItem(name: "q", value: link.header)]
        if provider == .binsearch { search.queryItems?.append(URLQueryItem(name: "max", value: "25")) }
        var request = URLRequest(url: search.url!)
        request.timeoutInterval = 15
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        let response: HTTPResult
        do { response = try await transport.perform(request) }
        catch is CancellationError { throw CancellationError() }
        catch let error as URLError where error.code == .cancelled { throw CancellationError() }
        catch { throw RelayError.message("The search service is unavailable.") }
        try Task.checkCancellation()
        guard (200..<300).contains(response.status) else {
            throw RelayError.message("The search service returned HTTP \(response.status).")
        }
        guard response.data.count <= 2 * 1024 * 1024 else {
            throw RelayError.message("The search response exceeds the supported size.")
        }
        let tags = SearchHTML.tags(in: String(decoding: response.data, as: UTF8.self))
        let result = provider == .king ? kingDownload(tags, origin: origin) : binsearchDownload(tags, origin: origin)
        guard let result else { throw RelayError.message("No download link was found in the search response.") }
        return result
    }

    private func kingDownload(_ tags: [SearchHTML.Tag], origin: URL) -> URL? {
        for tag in tags where !tag.isClosing && tag.name == "a" {
            guard let href = tag.attributes["href"],
                  let url = URL(string: href, relativeTo: origin)?.absoluteURL,
                  url.scheme == "https", url.host == origin.host,
                  url.user == nil, url.password == nil,
                  url.path.hasPrefix("/nzb:") else { continue }
            return url
        }
        return nil
    }

    private func binsearchDownload(_ tags: [SearchHTML.Tag], origin: URL) -> URL? {
        var action: URL?
        var fields: [URLQueryItem] = []
        var hasSelection = false

        func downloadURL() -> URL? {
            guard let action, hasSelection else { return nil }
            var url = URLComponents(url: action, resolvingAgainstBaseURL: false)!
            url.queryItems = (url.queryItems ?? []) + fields
            return url.url
        }

        for tag in tags {
            if tag.name == "form" {
                if tag.isClosing {
                    if let result = downloadURL() { return result }
                    action = nil
                } else {
                    action = nil; fields = []; hasSelection = false
                    let method = tag.attributes["method"]?.lowercased() ?? "get"
                    if method == "get", let target = tag.attributes["action"],
                       let url = URL(string: target, relativeTo: origin)?.absoluteURL,
                       url.scheme == "https", url.host == origin.host,
                       url.user == nil, url.password == nil,
                       url.path == "/nzb" || url.path == "/nzb/" {
                        action = url
                    }
                }
            } else if action != nil, !tag.isClosing, tag.name == "input",
                      let name = tag.attributes["name"], !name.isEmpty,
                      tag.attributes["disabled"] == nil {
                switch tag.attributes["type"]?.lowercased() ?? "text" {
                case "hidden": fields.append(URLQueryItem(name: name, value: tag.attributes["value"] ?? ""))
                case "checkbox":
                    if !hasSelection {
                        fields.append(URLQueryItem(name: name, value: tag.attributes["value"] ?? "on"))
                        hasSelection = true
                    }
                default: break
                }
            }
        }
        return downloadURL()
    }
}
