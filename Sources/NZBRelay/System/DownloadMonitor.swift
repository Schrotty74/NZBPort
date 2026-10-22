import Foundation
import Observation
import RelayCore
import UserNotifications

@MainActor @Observable
final class DownloadMonitor: NSObject, UNUserNotificationCenterDelegate {
    private let client: SABClient
    private let defaults: UserDefaults
    private var connection: ServerConnection?
    private var generation = 0
    private var pollTask: Task<Void, Never>?
    private var completions = CompletionTracker()
    private var visible = false
    private(set) var queue: SABQueueSnapshot?
    private(set) var history: [SABHistoryJob] = []
    private(set) var error: (any Error)?
    private(set) var refreshing = false
    private(set) var changing = false
    private(set) var notificationsEnabled: Bool

    init(client: SABClient, defaults: UserDefaults) {
        self.client = client
        self.defaults = defaults
        notificationsEnabled = defaults.bool(forKey: "downloadNotifications")
        super.init()
    }

    func installNotificationDelegate() {
        UNUserNotificationCenter.current().delegate = self
    }

    func configure(_ connection: ServerConnection?) {
        generation += 1
        pollTask?.cancel(); pollTask = nil
        self.connection = connection
        queue = nil; history = []; error = nil; refreshing = false
        completions = CompletionTracker()
        updatePolling()
    }

    func setVisible(_ visible: Bool) { self.visible = visible; updatePolling() }
    func trackSubmitted(_ ids: [String]) { completions.track(ids) }

    func setNotifications(_ enabled: Bool) async {
        if enabled {
            do {
                let allowed = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                notificationsEnabled = allowed
                if !allowed { error = RelayError.message("Notifications are not allowed in macOS settings.") }
            } catch { self.error = error; notificationsEnabled = false }
        } else { notificationsEnabled = false }
        defaults.set(notificationsEnabled, forKey: "downloadNotifications")
        updatePolling()
    }

    private func updatePolling() {
        guard connection != nil, visible || notificationsEnabled else { pollTask?.cancel(); pollTask = nil; return }
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refresh()
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
            }
        }
    }

    func refresh() async {
        guard let connection, !refreshing else { return }
        let revision = generation
        refreshing = true
        defer { if revision == generation { refreshing = false } }
        do {
            async let queueResult = client.queue(connection)
            async let historyResult = client.history(connection, limit: 25)
            let (nextQueue, nextHistory) = try await (queueResult, historyResult)
            guard !Task.isCancelled, revision == generation else { return }
            queue = nextQueue
            history = nextHistory
            error = nil
            let completed = completions.observe(nextHistory)
            if notificationsEnabled {
                for job in completed { await notify(job) }
            }
        } catch is CancellationError { }
        catch { if revision == generation, !Task.isCancelled { self.error = error } }
    }

    func control(_ action: SABQueueAction, jobID: String? = nil) async {
        guard let connection, !changing else { return }
        changing = true
        defer { changing = false }
        do {
            if let jobID { try await client.setJob(action, id: jobID, connection: connection) }
            else { try await client.setQueue(action, connection: connection) }
            await refresh()
        } catch { self.error = error }
    }

    private func notify(_ job: SABHistoryJob) async {
        let content = UNMutableNotificationContent()
        content.title = job.failed ? L("Download fehlgeschlagen") : L("Download abgeschlossen")
        content.body = job.title
        content.sound = .default
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(
            identifier: "NZBPort." + job.id, content: content, trigger: nil
        ))
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
        willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
