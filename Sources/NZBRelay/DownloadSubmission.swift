import Foundation
import CryptoKit
import RelayCore

enum DownloadSubmission: Identifiable {
    case link(NZBLink)
    case file(NZBFile)

    var id: UUID { switch self { case .link(let value): value.id; case .file(let value): value.id } }
    var title: String { switch self { case .link(let value): value.title; case .file(let value): value.title } }
    var password: String? { switch self { case .link(let value): value.password; case .file: nil } }
    var byteCount: Int { switch self { case .link: 0; case .file(let file): file.data.count } }

    func fingerprint(server: URL) -> String {
        var bytes = Data(server.absoluteString.utf8)
        bytes.append(0)
        switch self {
        case .link(let link):
            bytes.append(contentsOf: "link\0".utf8)
            bytes.append(contentsOf: link.header.utf8)
            for group in link.groups.sorted() { bytes.append(0); bytes.append(contentsOf: group.utf8) }
        case .file(let file):
            bytes.append(contentsOf: "file\0".utf8)
            bytes.append(file.data)
        }
        return SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
}

/// Only hashes and timestamps, kept in memory for this session.
struct SubmissionLedger {
    private var attempts: [String: Date] = [:]
    private let lifetime: TimeInterval = 600

    mutating func contains(_ fingerprint: String, now: Date = Date()) -> Bool {
        attempts = attempts.filter { now.timeIntervalSince($0.value) < lifetime }
        return attempts[fingerprint] != nil
    }
    mutating func record(_ fingerprint: String, now: Date = Date()) {
        attempts = attempts.filter { now.timeIntervalSince($0.value) < lifetime }
        attempts[fingerprint] = now
    }
}

extension SABPriority {
    var title: String {
        switch self { case .low: L("Niedrig"); case .normal: L("Normal"); case .high: L("Hoch"); case .force: L("Sofort") }
    }
}
