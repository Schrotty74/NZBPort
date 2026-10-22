import Foundation
import RelayCore

/// Establishes a baseline and reports only newly terminal jobs, once per session.
struct CompletionTracker {
    private var seen = Set<String>()
    private var submitted = Set<String>()
    private var hasBaseline = false

    mutating func track(_ ids: [String]) { submitted.formUnion(ids) }

    mutating func observe(_ history: [SABHistoryJob]) -> [SABHistoryJob] {
        let terminal = history.filter { $0.failed || $0.status.caseInsensitiveCompare("Completed") == .orderedSame }
        let updates = terminal.filter { !seen.contains($0.id) && (hasBaseline || submitted.contains($0.id)) }
        seen.formUnion(terminal.map(\.id))
        submitted.subtract(terminal.map(\.id))
        if seen.count > 500 { seen = Set(terminal.map(\.id)) }
        hasBaseline = true
        return updates
    }
}
