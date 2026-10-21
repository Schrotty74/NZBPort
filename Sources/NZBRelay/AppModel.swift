import AppKit
import Observation
import RelayCore

enum Screen { case downloads, settings }
struct Notice: Equatable {
    let text: String
    let isError: Bool
}

@MainActor @Observable
final class AppModel {
    var screen: Screen = .downloads
    let appearanceSettings = AppearanceSettings()
    var address = "http://localhost:8080/api"
    var key = ""
    private(set) var categories: [String] = []
    private(set) var preferences = CategoryPreferences()
    private(set) var current: NZBLink?
    private(set) var pending: [NZBLink] = []
    private(set) var busy = false
    private(set) var sending = false
    private(set) var progress = ""
    var notice: Notice?
    var query = ""
    private(set) var configured = false
    private(set) var handlerRegistered = false
    private(set) var registeringHandler = false
    private let client = SABClient()
    private let resolver = NZBResolver()
    private var savedAddress = ""
    private var savedKey = ""
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored var closeAfterSuccess: (() -> Void)?

    init() {
        address = UserDefaults.standard.string(forKey: "serverAddress") ?? address
        if let data = UserDefaults.standard.data(forKey: "categoryPreferences"),
           let decoded = try? JSONDecoder().decode(CategoryPreferences.self, from: data) {
            preferences = decoded
        }
        key = UserDefaults.standard.string(forKey: "sabAPIKey") ?? ""
        configured = (try? ServerConnection(address: address, apiKey: key)) != nil
        savedAddress = address
        savedKey = key
        if !configured { screen = .settings }
    }

    var visibleCategories: [String] {
        preferences.visible(in: categories).filter {
            query.isEmpty || categoryName($0).localizedCaseInsensitiveContains(query)
        }
    }
    var hiddenCategories: [String] {
        preferences.hidden.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
    var shownCount: Int { preferences.visible(in: categories).count }
    var serverHost: String { URL(string: address)?.host ?? "SABnzbd" }

    func receive(_ urls: [URL]) {
        for url in urls {
            do {
                let link = try NZBLink(url.absoluteString)
                pending.append(link)
            } catch { notice = Notice(text: error.localizedDescription, isError: true) }
        }
        if current == nil, !sending, !pending.isEmpty { advance() }
    }

    func paste() {
        guard let text = NSPasteboard.general.string(forType: .string) else {
            notice = Notice(text: "In der Zwischenablage liegt kein Link.", isError: true)
            return
        }
        do {
            let link = try NZBLink(text)
            pending.append(link)
            if current == nil, !sending { advance() }
        } catch { notice = Notice(text: error.localizedDescription, isError: true) }
    }

    private func advance() {
        task?.cancel()
        query = ""
        if !pending.isEmpty { current = pending.removeFirst() }
        if configured {
            screen = .downloads
            loadCategories()
        } else {
            screen = .settings
            notice = Notice(text: "Bitte zuerst die Verbindung zu SABnzbd einrichten.", isError: false)
        }
    }

    func loadCategories() {
        guard !sending else { return }
        task?.cancel()
        busy = true
        progress = "Kategorien laden …"
        notice = nil
        categories = []
        let useDraft = screen == .settings
        task = Task {
            defer { if !Task.isCancelled { busy = false } }
            do {
                let connection = try ServerConnection(address: useDraft ? address : savedAddress, apiKey: useDraft ? key : savedKey)
                let result = try await client.categories(connection)
                try Task.checkCancellation()
                categories = result
            } catch is CancellationError { }
            catch let error as URLError where error.code == .cancelled { }
            catch {
                guard !Task.isCancelled else { return }
                notice = Notice(text: error.localizedDescription, isError: true)
            }
        }
    }

    func save() {
        guard !busy else { return }
        do {
            let connection = try ServerConnection(address: address, apiKey: key)
            address = connection.endpoint.absoluteString
            key = connection.apiKey
            savedAddress = address
            savedKey = key
            UserDefaults.standard.set(address, forKey: "serverAddress")
            UserDefaults.standard.set(key, forKey: "sabAPIKey")
            configured = true
            screen = .downloads
            loadCategories()
        } catch { notice = Notice(text: error.localizedDescription, isError: true) }
    }

    func setVisible(_ visible: Bool, category: String) {
        preferences.setVisible(visible, category: category)
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: "categoryPreferences")
        }
    }

    func send(category: String) {
        guard !busy, let link = current else { return }
        busy = true
        sending = true
        progress = "NZB suchen …"
        notice = nil
        task = Task {
            do {
                let connection = try ServerConnection(address: savedAddress, apiKey: savedKey)
                let download = try await resolver.resolve(link) { [self] provider in
                    await self.showSearchProvider(provider)
                }
                try Task.checkCancellation()
                progress = "An SABnzbd senden …"
                try await client.send(link, download: download, category: category, connection: connection)
                busy = false
                sending = false
                current = nil
                if pending.isEmpty { closeAfterSuccess?() }
                else { advance() }
            } catch {
                busy = false
                sending = false
                notice = Notice(text: error.localizedDescription, isError: true)
            }
        }
    }

    func discardCurrent() {
        guard !sending else { return }
        task?.cancel()
        busy = false
        current = nil
        notice = nil
        if !pending.isEmpty { advance() }
    }

    private func showSearchProvider(_ provider: String) {
        progress = "NZB suchen: \(provider) …"
    }

    func registerHandler() {
        guard !busy, !registeringHandler else { return }
        registeringHandler = true
        Task {
            defer { registeringHandler = false }
            do {
                try await NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpenURLsWithScheme: "nzblnk")
                handlerRegistered = true
                notice = Notice(text: "NZBPort öffnet jetzt NZBlnk-Links auf diesem Mac.", isError: false)
            } catch {
                notice = Notice(text: "Die Zuordnung konnte nicht geändert werden. Bitte die App an ihrem endgültigen Ort öffnen und erneut versuchen.", isError: true)
            }
        }
    }

    func openSettings() {
        guard !sending else { return }
        address = savedAddress
        key = savedKey
        screen = .settings
        notice = nil
    }

    func categoryName(_ category: String) -> String { category == "*" || category.isEmpty ? "Standard" : category }
}
