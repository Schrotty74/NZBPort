import Foundation

/// Searches Newznab-compatible RSS APIs and resolves downloads without forwarding API credentials.
public actor NewznabClient: NZBSearchProvider {
    public static let userAgent = "NZBPort/0.2.7 (+https://github.com/Schrotty74/NZBPort)"
    public enum Service: Sendable, Equatable { case treasureMaps, newzBay, ninjaCentral, drunkenSlug, nzbFinder, videothek }

    nonisolated public var name: String {
        switch service { case .treasureMaps: "Treasure Maps"; case .newzBay: "NewzBay"; case .ninjaCentral: "NinjaCentral"; case .drunkenSlug: "DrunkenSlug"; case .nzbFinder: "NZBFinder"; case .videothek: "Videothek.io" }
    }

    private let service: Service
    private let apiKey: String
    private let transport: any HTTPTransport
    private let endpoint: URL

    public init(apiKey: String, service: Service, transport: (any HTTPTransport)? = nil) {
        self.apiKey = apiKey
        self.service = service
        self.endpoint = URL(string: {
            switch service {
            case .treasureMaps: "https://treasure-maps.com/api"
            case .newzBay: "https://newzbay.cc/api"
            case .ninjaCentral: "https://ninjacentral.co.za/api"
            case .drunkenSlug: "https://drunkenslug.com/api"
            case .nzbFinder: "https://nzbfinder.ws/api"
            case .videothek: "https://videothek.io/api"
            }
        }())!
        self.transport = transport ?? NewznabTransport(service: service)
    }

    public func resolve(_ link: NZBLink) async throws -> URL {
        guard !apiKey.isEmpty else { throw RelayError.message("The search service requires an API key.") }
        let title = Self.canonicalTitle(link.title)
        guard link.hasTitle, !title.isEmpty else {
            throw RelayError.message("The search service needs a release title to search.")
        }

        let query: [(String, String)] = service == .treasureMaps
            ? [("t", "search"), ("q", link.title), ("apikey", apiKey)]
            : [("t", "search"), ("q", link.title), ("o", "xml"), ("apikey", apiKey)]
        let request = try makeRequest(query, accept: "application/rss+xml, application/xml, text/xml")
        let result = try await perform(request, failure: "The search service is unavailable. Check the search service and network connection.")
        if service == .nzbFinder, result.data.count <= 2 * 1024 * 1024 {
            let providerResponse = NewznabRSSParser.parse(result.data)
            if providerResponse.apiErrorCode == "102" {
                throw RelayError.message("NZBFinder requires a premium membership for API access.")
            }
        }
        guard (200..<300).contains(result.status) else {
            if result.status == 429 { throw RelayError.message("The search service rate limit was reached. Wait a while, then try again.") }
            throw RelayError.message("The search service returned an HTTP error. Please try again later.")
        }
        guard result.data.count <= 2 * 1024 * 1024 else {
            throw RelayError.message("The search service response exceeds the supported size.")
        }

        let parsed = NewznabRSSParser.parse(result.data)
        if parsed.apiError { throw RelayError.message("The search service rejected the API key or search request.") }
        guard parsed.validXML else { throw RelayError.message("The search service returned an invalid XML search response.") }
        let exact = parsed.items.filter { Self.canonicalTitle($0.title) == title }
        guard !exact.isEmpty else { throw RelayError.message("The search service found no exact title match.") }
        guard exact.count == 1, let item = exact.first else {
            throw RelayError.message("The search service found multiple exact title matches. The result is ambiguous.")
        }

        switch service {
        case .treasureMaps:
            guard let download = item.enclosure, Self.isSafeTreasureMapsDownload(download) else {
                throw RelayError.message("The search service returned an invalid NZB download link.")
            }
            return download
        case .newzBay, .ninjaCentral, .drunkenSlug, .nzbFinder, .videothek:
            if service == .videothek {
                for url in [item.enclosure, URL(string: item.link.trimmingCharacters(in: .whitespacesAndNewlines))].compactMap({ $0 }) {
                    if let id = authenticatedDownloadIdentifier(url, apiKey: apiKey) {
                        return try buildAuthenticatedDownload(id: id)
                    }
                }
            }
            guard let id = item.identifier(host: endpoint.host!, allowUUID: service == .nzbFinder || service == .videothek,
                                           allowLongHex: service == .videothek || service == .drunkenSlug || service == .nzbFinder) else {
                throw RelayError.message("The search service returned an invalid NZB download link.")
            }
            return try buildAuthenticatedDownload(id: id)
        }
    }

    /// API-key-bearing NZB URLs are fetched here; callers receive the NZB bytes, never that URL.
    public func fetchIfApplicable(_ download: URL) async throws -> NZBFile? {
        let identifier: String
        switch service {
        case .treasureMaps:
            guard download.host?.lowercased() == Self.fileHost else { return nil }
            guard Self.isSafeTreasureMapsDownload(download) else {
                throw RelayError.message("The search service returned an invalid NZB download link.")
            }
            identifier = download.lastPathComponent
        case .newzBay, .ninjaCentral, .drunkenSlug, .nzbFinder, .videothek:
            guard download.host?.lowercased() == endpoint.host else { return nil }
            guard let id = authenticatedDownloadIdentifier(download, apiKey: apiKey) else {
                throw RelayError.message("The search service returned an invalid NZB download link.")
            }
            identifier = id
        }
        var request = URLRequest(url: download)
        request.timeoutInterval = 25
        request.setValue("application/x-nzb, application/xml, text/xml", forHTTPHeaderField: "Accept")
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        let result = try await perform(request, failure: "The search service could not download the NZB file.")
        guard (200..<300).contains(result.status) else {
            throw RelayError.message("The search service could not download the NZB file.")
        }
        return try NZBFile(data: result.data, filename: identifier + ".nzb")
    }

    private func makeRequest(_ fields: [(String, String)], accept: String) throws -> URLRequest {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        components.percentEncodedQuery = String(decoding: FormEncoding.encode(fields), as: UTF8.self)
        guard let url = components.url else { throw RelayError.message("The search service could not build the search request.") }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue(accept, forHTTPHeaderField: "Accept")
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    private func buildAuthenticatedDownload(id: String) throws -> URL {
        guard isValidIdentifier(id) else { throw RelayError.message("The search service returned an invalid NZB download link.") }
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        components.percentEncodedQuery = String(decoding: FormEncoding.encode([
            ("t", "get"), ("id", id), ("apikey", apiKey)
        ]), as: UTF8.self)
        guard let url = components.url else { throw RelayError.message("The search service returned an invalid NZB download link.") }
        return url
    }

    private func isValidIdentifier(_ value: String) -> Bool {
        NewznabClientIdentifier.isValid(value, allowUUID: service == .nzbFinder || service == .videothek, allowLongHex: service == .videothek || service == .drunkenSlug || service == .nzbFinder)
    }

    static func allowsNinjaRedirect(from original: URL?, to destination: URL?) -> Bool {
        guard let original, let destination,
              let source = URLComponents(url: original, resolvingAgainstBaseURL: false),
              let target = URLComponents(url: destination, resolvingAgainstBaseURL: false),
              source.scheme == "https", source.host == "ninjacentral.co.za",
              source.path == "/api", source.queryItems?.first(where: { $0.name == "t" })?.value == "get",
              target.scheme == "https", target.host == source.host,
              target.user == nil, target.password == nil, target.port == nil, target.fragment == nil
        else { return false }
        return true
    }

    static func allowsDrunkenSlugRedirect(from original: URL?, to destination: URL?) -> Bool {
        guard let original, let destination,
              let source = URLComponents(url: original, resolvingAgainstBaseURL: false),
              let target = URLComponents(url: destination, resolvingAgainstBaseURL: false),
              source.scheme == "https", source.host == "drunkenslug.com", source.path == "/api",
              source.queryItems?.contains(URLQueryItem(name: "t", value: "get")) == true,
              target.scheme == "https", target.host == source.host, target.path == "/getnzb",
              target.user == nil, target.password == nil, target.port == nil, target.fragment == nil,
              let items = target.queryItems else { return false }
        return ["i", "r"].allSatisfy { name in
            let values = items.filter { $0.name == name }
            return values.count == 1 && values[0].value?.isEmpty == false
        }
    }

    static func allowsNewzBayRedirect(from original: URL?, to destination: URL?) -> Bool {
        guard let original, let destination,
              let source = URLComponents(url: original, resolvingAgainstBaseURL: false),
              let target = URLComponents(url: destination, resolvingAgainstBaseURL: false),
              source.scheme == "https", source.host == "newzbay.cc", source.path == "/api",
              source.queryItems?.contains(URLQueryItem(name: "t", value: "get")) == true,
              target.scheme == "https", target.host == source.host,
              target.user == nil, target.password == nil, target.port == nil, target.fragment == nil
        else { return false }
        if target.path == "/getnzb", let items = target.queryItems {
            return ["id", "r"].allSatisfy { name in
                let values = items.filter { $0.name == name }
                return values.count == 1 && values[0].value?.isEmpty == false
            }
        }
        let path = target.path.split(separator: "/")
        let sourceID = source.queryItems?.first(where: { $0.name == "id" })?.value
        return (2...3).contains(path.count) && path[0] == "getnzb" &&
            sourceID.map { path[1].caseInsensitiveCompare($0) == .orderedSame } == true
    }

    private func perform(_ request: URLRequest, failure: String.LocalizationValue) async throws -> HTTPResult {
        let result: HTTPResult
        do { result = try await transport.perform(request) }
        catch is CancellationError { throw CancellationError() }
        catch let error as URLError where error.code == .cancelled { throw CancellationError() }
        catch { throw RelayError.message(failure) }
        try Task.checkCancellation()
        return result
    }

    private static func canonicalTitle(_ title: String) -> String {
        let folded = title.lowercased()
        var result = String.UnicodeScalarView()
        var pendingSpace = false
        for scalar in folded.unicodeScalars {
            if scalar == "." || scalar == "_" || CharacterSet.whitespacesAndNewlines.contains(scalar) {
                pendingSpace = !result.isEmpty
            } else {
                if pendingSpace { result.append(" "); pendingSpace = false }
                result.append(scalar)
            }
        }
        return String(result)
    }

    private static let fileHost = "file.treasure-maps.com"


    private static func isSafeTreasureMapsDownload(_ url: URL) -> Bool {
        guard let c = URLComponents(url: url, resolvingAgainstBaseURL: false),
              c.scheme?.lowercased() == "https", c.host?.lowercased() == fileHost,
              c.user == nil, c.password == nil, c.port == nil,
              c.path.range(of: #"^/getnzb/[0-9a-fA-F]{32}$"#, options: .regularExpression) != nil,
              c.fragment == nil else { return false }
        let items = c.queryItems ?? []
        return items.count == 1 && items.first?.name == "r" && items.first?.value?.isEmpty == false
    }

    private func authenticatedDownloadIdentifier(_ url: URL, apiKey: String) -> String? {
        guard let c = URLComponents(url: url, resolvingAgainstBaseURL: false),
              c.scheme?.lowercased() == "https", c.host?.lowercased() == endpoint.host,
              c.user == nil, c.password == nil, c.port == nil, c.path == "/api", c.fragment == nil else { return nil }
        let items = c.queryItems ?? []
        guard items.count == 3 else { return nil }
        let values = Dictionary(items.compactMap { item in item.value.map { (item.name, $0) } }, uniquingKeysWith: { first, _ in first })
        guard values["t"] == "get", values["apikey"] == apiKey,
              let id = values["id"], isValidIdentifier(id) else { return nil }
        return id
    }
}

/// Ephemeral requests without cache or cookies; only approved NZB download redirects stay on the provider’s HTTPS host.
private struct NewznabTransport: HTTPTransport {
    let service: NewznabClient.Service
    func perform(_ request: URLRequest) async throws -> HTTPResult {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        let session = URLSession(configuration: configuration, delegate: NewznabRedirectDelegate(service: service), delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw RelayError.message("The service did not return an HTTP response.") }
        return HTTPResult(data: data, status: http.statusCode)
    }
}

private final class NewznabRedirectDelegate: NSObject, URLSessionTaskDelegate {
    let service: NewznabClient.Service

    init(service: NewznabClient.Service) { self.service = service }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        let allowed = switch service {
        case .newzBay: NewznabClient.allowsNewzBayRedirect(from: task.originalRequest?.url, to: request.url)
        case .ninjaCentral: NewznabClient.allowsNinjaRedirect(from: task.originalRequest?.url, to: request.url)
        case .drunkenSlug: NewznabClient.allowsDrunkenSlugRedirect(from: task.originalRequest?.url, to: request.url)
        default: false
        }
        completionHandler(allowed ? request : nil)
    }
}

private struct NewznabRSSItem {
    var title = ""
    var enclosure: URL?
    var link = ""
    var guid = ""
    var guidAttribute: String?
}

private struct NewznabRSSResult {
    var items: [NewznabRSSItem] = []
    var apiError = false
    var validXML = false
    var apiErrorCode: String?
}

private extension NewznabRSSItem {
    func identifier(host: String, allowUUID: Bool = false, allowLongHex: Bool = false) -> String? {
        for raw in [guidAttribute, guid].compactMap({ $0 }) {
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if NewznabClientIdentifier.isValid(value, allowUUID: allowUUID, allowLongHex: allowLongHex) { return value }
            if let url = URLComponents(string: value), url.scheme?.lowercased() == "https",
               url.host?.lowercased() == host, url.user == nil, url.password == nil,
               url.port == nil, url.fragment == nil {
                let pathParts = url.path.split(separator: "/")
                if pathParts.count == 2, pathParts[0] == "details", NewznabClientIdentifier.isValid(String(pathParts[1]), allowUUID: allowUUID, allowLongHex: allowLongHex) { return String(pathParts[1]) }
                if url.path == "/api", let id = url.queryItems?.first(where: { $0.name == "id" })?.value,
                   NewznabClientIdentifier.isValid(id, allowUUID: allowUUID, allowLongHex: allowLongHex) { return id }
            }
        }
        return nil
    }
}

private enum NewznabClientIdentifier {
    static func isValid(_ value: String, allowUUID: Bool = false, allowLongHex: Bool = false) -> Bool {
        if allowLongHex, value.utf8.count == 40 {
            return value.utf8.allSatisfy { (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }
        }
        let pattern = allowUUID
            ? #"^(?:[0-9a-fA-F]{32}|[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})$"#
            : #"^[0-9a-fA-F]{32}$"#
        return value.range(of: pattern, options: .regularExpression) != nil
    }
}

private final class NewznabRSSParser: NSObject, XMLParserDelegate {
    private var result = NewznabRSSResult()
    private var current: NewznabRSSItem?
    private var elements: [String] = []
    private var hasRSSRoot = false

    static func parse(_ data: Data) -> NewznabRSSResult {
        let delegate = NewznabRSSParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldResolveExternalEntities = false
        delegate.result.validXML = parser.parse() && delegate.hasRSSRoot
        return delegate.result
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes: [String: String] = [:]) {
        elements.append(elementName)
        switch elements {
        case ["rss"]: hasRSSRoot = true
        case ["error"]:
            result.apiError = true
            result.apiErrorCode = attributes["code"]
        case ["rss", "channel", "item"]:
            current = NewznabRSSItem()
            current?.guidAttribute = attributes["guid"] ?? attributes["id"]
        case ["rss", "channel", "item", "enclosure"]:
            if attributes["type"] == "application/x-nzb", let raw = attributes["url"] { current?.enclosure = URL(string: raw) }
        case ["rss", "channel", "item", "guid"]:
            if let value = attributes["id"] ?? attributes["value"] ?? attributes["url"] {
                current?.guidAttribute = value
            }
        default: break
        }
        if elements == ["rss", "channel", "item", "newznab:attr"],
           attributes["name"]?.lowercased() == "guid" {
            current?.guidAttribute = attributes["value"]
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if elements == ["rss", "channel", "item", "title"] { current?.title += string }
        if elements == ["rss", "channel", "item", "guid"] { current?.guid += string }
        if elements == ["rss", "channel", "item", "link"] { current?.link += string }
    }

    func parser(_ parser: XMLParser, foundCDATA data: Data) { self.parser(parser, foundCharacters: String(decoding: data, as: UTF8.self)) }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elements == ["rss", "channel", "item"], let current { result.items.append(current); self.current = nil }
        elements.removeLast()
    }

    func parser(_ parser: XMLParser, foundInternalEntityDeclarationWithName name: String, value: String?) { parser.abortParsing() }
    func parser(_ parser: XMLParser, foundExternalEntityDeclarationWithName name: String, publicID: String?, systemID: String?) { parser.abortParsing() }
}
