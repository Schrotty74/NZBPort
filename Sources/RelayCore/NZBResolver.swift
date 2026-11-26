import Foundation

public protocol NZBSearchProvider: Sendable {
    var name: String { get }
    func resolve(_ link: NZBLink) async throws -> URL
}

/// Serial fallback; a failure at one provider does not prevent the next search.
public actor NZBResolver {
    public enum Result: Sendable {
        case url(URL)
        case file(NZBFile)
    }

    private enum Provider: Sendable {
        case url(any NZBSearchProvider)
        case easynews(EasynewsClient)

        var name: String {
            switch self {
            case .url(let provider): provider.name
            case .easynews: IndexerPreferences.Indexer.easynews.rawValue
            }
        }

        var newznabClient: NewznabClient? {
            if case .url(let provider) = self { return provider as? NewznabClient }
            return nil
        }

        func resolve(_ link: NZBLink) async throws -> Result {
            switch self {
            case .url(let provider): .url(try await provider.resolve(link))
            case .easynews(let client): .file(try await client.fetch(link))
            }
        }
    }

    private let providers: [Provider]
    private let newznabClients: [NewznabClient]
    private let transport: any HTTPTransport

    public init(transport: any HTTPTransport = SessionTransport(), newznabClients: [NewznabClient] = [],
                preferences: IndexerPreferences? = nil, easynews: EasynewsClient? = nil) {
        let urlProviders: [any NZBSearchProvider] = [
            NZBIndexClient(transport: transport),
            WebNZBSearch(provider: .king, transport: transport),
            WebNZBSearch(provider: .binsearch, transport: transport)
        ] + newznabClients
        var available = urlProviders.map(Provider.url)
        if let easynews { available.append(.easynews(easynews)) }
        let selected: [Provider]
        if let preferences {
            selected = preferences.order.filter { !preferences.disabled.contains($0) }.compactMap { indexer in
                available.first { $0.name == indexer.rawValue }
            }
        } else {
            selected = available
        }
        self.transport = transport
        self.providers = selected
        self.newznabClients = selected.compactMap(\.newznabClient)
    }

    public init(providers: [any NZBSearchProvider]) {
        self.providers = providers.map(Provider.url)
        self.newznabClients = providers.compactMap { $0 as? NewznabClient }
        self.transport = SessionTransport()
    }

    private func fetchFile(_ download: URL) async throws -> NZBFile? {
        for client in newznabClients {
            if let file = try await client.fetchIfApplicable(download) { return file }
        }
        return nil
    }

    /// Resolves and downloads an NZB without sending it to SABnzbd.
    public func fileForExport(_ link: NZBLink, onAttempt: (@Sendable (String) async -> Void)? = nil) async throws -> NZBFile {
        let download: URL
        switch try await resolve(link, onAttempt: onAttempt) {
        case .file(let file):
            return try NZBExport.file(data: file.data, title: link.title, password: link.password)
        case .url(let url):
            download = url
        }
        guard Self.isAllowedPublicDownload(download) else {
            throw RelayError.message("The search service returned an invalid NZB download link.")
        }
        var request = URLRequest(url: download)
        request.timeoutInterval = 25
        request.setValue("application/x-nzb, application/xml, text/xml", forHTTPHeaderField: "Accept")
        let result: HTTPResult
        do { result = try await transport.perform(request) }
        catch is CancellationError { throw CancellationError() }
        catch let error as URLError where error.code == .cancelled { throw CancellationError() }
        catch { throw RelayError.message("The search service could not download the NZB file.") }
        try Task.checkCancellation()
        guard (200..<300).contains(result.status) else {
            throw RelayError.message("The search service could not download the NZB file.")
        }
        return try NZBExport.file(data: result.data, title: link.title, password: link.password)
    }

    private static func isAllowedPublicDownload(_ url: URL) -> Bool {
        guard let c = URLComponents(url: url, resolvingAgainstBaseURL: false),
              c.scheme?.lowercased() == "https", c.user == nil, c.password == nil,
              c.port == nil, c.fragment == nil else { return false }
        switch c.host?.lowercased() {
        case "nzbindex.com": return c.path.range(of: #"^/api/download/[A-Za-z0-9_-]{1,128}\.nzb$"#, options: .regularExpression) != nil
        case "www.nzbking.com": return c.path.hasPrefix("/nzb:")
        case "www.binsearch.info": return c.path == "/nzb" || c.path == "/nzb/"
        default: return false
        }
    }

    public func resolve(_ link: NZBLink, onAttempt: (@Sendable (String) async -> Void)? = nil) async throws -> Result {
        guard !providers.isEmpty else { throw RelayError.message("No search services are enabled and configured.") }
        var failures: [String] = []
        var found: Result?
        for provider in providers {
            try Task.checkCancellation()
            await onAttempt?(provider.name)
            do {
                let result = try await provider.resolve(link)
                try Task.checkCancellation()
                found = result
                break
            } catch is CancellationError { throw CancellationError() }
            catch let error as URLError where error.code == .cancelled { throw CancellationError() }
            catch { failures.append(provider.name + ": " + error.localizedDescription) }
        }
        if let found {
            if case .url(let url) = found, let file = try await fetchFile(url) { return .file(file) }
            return found
        }
        throw RelayError.message("No NZB was found by any search service.\n\(failures.joined(separator: "\n"))")
    }
}
