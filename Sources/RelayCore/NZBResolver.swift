import Foundation

public protocol NZBSearchProvider: Sendable {
    var name: String { get }
    func resolve(_ link: NZBLink) async throws -> URL
}

/// Serial fallback; a failure at one provider does not prevent the next search.
public actor NZBResolver {
    private let providers: [any NZBSearchProvider]

    public init(transport: any HTTPTransport = SessionTransport()) {
        providers = [NZBIndexClient(transport: transport),
                     WebNZBSearch(provider: .king, transport: transport),
                     WebNZBSearch(provider: .binsearch, transport: transport)]
    }

    public init(providers: [any NZBSearchProvider]) { self.providers = providers }

    public func resolve(_ link: NZBLink, onAttempt: (@Sendable (String) async -> Void)? = nil) async throws -> URL {
        var failures: [String] = []
        for provider in providers {
            try Task.checkCancellation()
            await onAttempt?(provider.name)
            do {
                let url = try await provider.resolve(link)
                try Task.checkCancellation()
                return url
            } catch is CancellationError { throw CancellationError() }
            catch let error as URLError where error.code == .cancelled { throw CancellationError() }
            catch { failures.append(provider.name + ": " + error.localizedDescription) }
        }
        throw RelayError.message("No NZB was found by any search service.\n\(failures.joined(separator: "\n"))")
    }
}
