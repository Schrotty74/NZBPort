import Foundation

public enum SABPriority: Int, CaseIterable, Identifiable, Sendable {
    case low = -1
    case normal = 0
    case high = 1
    case force = 2
    public var id: Int { rawValue }
}

public struct SendOptions: Sendable {
    public var priority: SABPriority
    public var addPaused: Bool
    public init(priority: SABPriority = .normal, addPaused: Bool = false) {
        self.priority = priority
        self.addPaused = addPaused
    }
}

public struct SABJob: Sendable, Identifiable {
    public let id: String
    public let title: String
    public let status: String
    public let progress: Double
    public let category: String
    public init(id: String, title: String, status: String, progress: Double, category: String) {
        self.id = id; self.title = title; self.status = status
        self.progress = min(1, max(0, progress)); self.category = category
    }
}

public struct SABQueueSnapshot: Sendable {
    public let jobs: [SABJob]
    public let speed: String
    public let timeLeft: String
    public let paused: Bool
    public let remainingSize: String
    public init(jobs: [SABJob], speed: String, timeLeft: String, paused: Bool, remainingSize: String = "") {
        self.jobs = jobs; self.speed = speed; self.timeLeft = timeLeft; self.paused = paused; self.remainingSize = remainingSize
    }
}

public struct SABHistoryJob: Sendable, Identifiable {
    public let id: String
    public let title: String
    public let status: String
    public let failed: Bool
    public init(id: String, title: String, status: String, failed: Bool) {
        self.id = id; self.title = title; self.status = status; self.failed = failed
    }
}

public enum SABQueueAction: Equatable, Sendable { case pause, resume }
