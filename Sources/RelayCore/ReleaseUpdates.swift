import Foundation

public struct ReleaseUpdate: Sendable {
    public let version: String
    public let url: URL
    public let isPrerelease: Bool

    public init(version: String, url: URL, isPrerelease: Bool) {
        self.version = version
        self.url = url
        self.isPrerelease = isPrerelease
    }
}

public actor ReleaseUpdates {
    private let transport: any HTTPTransport
    private let endpoint = URL(string: "https://api.github.com/repos/Schrotty74/NZBPort/releases?per_page=100")!

    public init(transport: any HTTPTransport = SessionTransport()) { self.transport = transport }

    public func latest(currentVersion: String, includePrereleases: Bool) async throws -> ReleaseUpdate? {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.httpShouldHandleCookies = false
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let response = try await transport.perform(request)
        guard (200..<300).contains(response.status),
              let releases = try? JSONDecoder().decode([GitHubRelease].self, from: response.data) else {
            throw RelayError.message("Could not check for updates.")
        }
        guard let current = SemanticVersion(currentVersion) else { return nil }
        return releases.compactMap { release -> (ReleaseUpdate, SemanticVersion)? in
            guard !release.draft, (includePrereleases || !release.prerelease),
                  let version = SemanticVersion(release.tagName), version > current,
                  let url = Self.validURL(release.htmlURL, tag: release.tagName) else { return nil }
            return (ReleaseUpdate(version: release.tagName, url: url, isPrerelease: release.prerelease), version)
        }.max { $0.1 < $1.1 }?.0
    }

    private static func validURL(_ value: String, tag: String) -> URL? {
        guard let url = URL(string: value), url.scheme == "https", url.host == "github.com",
              url.user == nil, url.password == nil, url.port == nil,
              url.path == "/Schrotty74/NZBPort/releases/tag/\(tag)", url.query == nil, url.fragment == nil else { return nil }
        return url
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: String
    let prerelease: Bool
    let draft: Bool
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name", htmlURL = "html_url", prerelease, draft
    }
}

private struct SemanticVersion: Comparable {
    let components: [Int]
    private let prerelease: [Identifier]

    init?(_ raw: String) {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.first == "v" || value.first == "V" { value.removeFirst() }
        value = value.split(separator: "+", maxSplits: 1).first.map(String.init) ?? value
        let parts = value.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let numeric = parts[0].split(separator: ".", omittingEmptySubsequences: false)
        guard !numeric.isEmpty, numeric.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }),
              let parsed = numeric.map({ Int($0) }).reduce(Optional<[Int]>([]), { acc, part in
                  guard let acc, let part else { return nil }; return acc + [part]
              }) else { return nil }
        components = parsed
        if parts.count == 2 {
            let ids = parts[1].split(separator: ".", omittingEmptySubsequences: false)
            guard !ids.isEmpty, ids.allSatisfy({ !$0.isEmpty && $0.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }) }) else { return nil }
            prerelease = ids.map { id in
                let text = String(id)
                if text.allSatisfy(\.isNumber), let number = Int(text) { return .number(number) }
                return .text(text)
            }
        } else { prerelease = [] }
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        for index in 0..<max(lhs.components.count, rhs.components.count) {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right { return left < right }
        }
        if lhs.prerelease.isEmpty != rhs.prerelease.isEmpty { return !lhs.prerelease.isEmpty }
        for index in 0..<min(lhs.prerelease.count, rhs.prerelease.count) where lhs.prerelease[index] != rhs.prerelease[index] {
            return lhs.prerelease[index] < rhs.prerelease[index]
        }
        return lhs.prerelease.count < rhs.prerelease.count
    }

    private enum Identifier: Comparable {
        case number(Int), text(String)
        static func < (lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case let (.number(a), .number(b)): a < b
            case (.number, .text): true
            case (.text, .number): false
            case let (.text(a), .text(b)): a < b
            }
        }
    }
}
