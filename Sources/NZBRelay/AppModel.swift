import AppKit
import UniformTypeIdentifiers
import Observation
import RelayCore

enum Screen { case downloads, settings, categories, overview, updates }
struct Notice: Equatable {
    private let id = UUID()
    private let message: String.LocalizationValue?
    private let error: (any Error)?
    let isError: Bool

    init(text: String.LocalizationValue, isError: Bool) {
        message = text
        error = nil
        self.isError = isError
    }

    init(error: any Error) {
        message = nil
        self.error = error
        isError = true
    }

    var text: String {
        if let message { return L(message) }
        return error?.localizedDescription ?? ""
    }

    static func == (lhs: Notice, rhs: Notice) -> Bool { lhs.id == rhs.id }
}

@MainActor @Observable
final class AppModel {
    private static let treasureMapsPreference = "treasureMapsAPIKey"
    private static let newzBayPreference = "newzBayAPIKey"
    private static let ninjaCentralPreference = "ninjaCentralAPIKey"
    private static let drunkenSlugPreference = "drunkenSlugAPIKey"
    private static let nzbFinderPreference = "nzbFinderAPIKey"

    var screen: Screen = .downloads
    let appearanceSettings: AppearanceSettings
    let languageSettings: LanguageSettings
    let loginItemSettings = LoginItemSettings()
    let updateSettings: UpdateSettings
    let monitor: DownloadMonitor
    var selectedPriority = SABPriority.normal
    var addPaused = false
    var duplicateCategory: String?
    private var submissionLedger = SubmissionLedger()
    var address = "http://localhost:8080/api"
    var key = ""
    var treasureMapsKey = ""
    var newzBayKey = ""
    var ninjaCentralKey = ""
    var drunkenSlugKey = ""
    var nzbFinderKey = ""
    var newCategoryName = ""
    var categoryToDelete: String?
    private(set) var categoryMutationInProgress = false
    private(set) var categories: [String] = []
    private(set) var preferences = CategoryPreferences()
    private(set) var current: DownloadSubmission?
    private(set) var pending: [DownloadSubmission] = []
    private(set) var busy = false
    private(set) var sending = false
    private(set) var exporting = false
    private(set) var exportFile: NZBFile?
    var exportPresented = false
    private(set) var progress: String.LocalizationValue = ""
    var notice: Notice?
    var query = ""
    private(set) var configured = false
    private(set) var handlerRegistered = false
    private(set) var registeringHandler = false
    private let client: SABClient
    private let exportResolver: NZBResolver?
    @ObservationIgnored private let defaults: UserDefaults
    private var categoryLoadRevision = 0
    private var savedAddress = ""
    private var savedKey = ""
    private var savedTreasureMapsKey = ""
    private var savedNewzBayKey = ""
    private var savedNinjaCentralKey = ""
    private var savedDrunkenSlugKey = ""
    private var savedNZBFinderKey = ""
    @ObservationIgnored private(set) var task: Task<Void, Never>?
    @ObservationIgnored var closeAfterSuccess: (() -> Void)?

    init(defaults: UserDefaults = .standard, client: SABClient = SABClient(), exportResolver: NZBResolver? = nil) {
        self.defaults = defaults
        self.client = client
        self.exportResolver = exportResolver
        updateSettings = UpdateSettings(defaults: defaults)
        monitor = DownloadMonitor(client: client, defaults: defaults)
        appearanceSettings = AppearanceSettings(defaults: defaults)
        languageSettings = LanguageSettings(defaults: defaults)
        address = defaults.string(forKey: "serverAddress") ?? address
        if let data = defaults.data(forKey: "categoryPreferences"),
           let decoded = try? JSONDecoder().decode(CategoryPreferences.self, from: data) {
            preferences = decoded
        }
        key = defaults.string(forKey: "sabAPIKey") ?? ""
        treasureMapsKey = defaults.string(forKey: Self.treasureMapsPreference) ?? ""
        newzBayKey = defaults.string(forKey: Self.newzBayPreference) ?? ""
        ninjaCentralKey = defaults.string(forKey: Self.ninjaCentralPreference) ?? ""
        drunkenSlugKey = defaults.string(forKey: Self.drunkenSlugPreference) ?? ""
        nzbFinderKey = defaults.string(forKey: Self.nzbFinderPreference) ?? ""
        configured = (try? ServerConnection(address: address, apiKey: key)) != nil
        savedAddress = address
        savedKey = key
        savedTreasureMapsKey = treasureMapsKey
        savedNewzBayKey = newzBayKey
        savedNinjaCentralKey = ninjaCentralKey
        savedDrunkenSlugKey = drunkenSlugKey
        savedNZBFinderKey = nzbFinderKey
        if !configured { screen = .settings }
        monitor.configure(try? ServerConnection(address: savedAddress, apiKey: savedKey))
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
                guard pending.count < 50 else { throw RelayError.message("Too many pending downloads.") }
                let submission: DownloadSubmission = url.isFileURL ? .file(try NZBFile(url: url)) : .link(try NZBLink(url.absoluteString))
                guard pending.reduce(current?.byteCount ?? 0, { $0 + $1.byteCount }) + submission.byteCount <= 64 * 1024 * 1024 else {
                    throw RelayError.message("Pending NZB files exceed 64 MiB.")
                }
                pending.append(submission)
            } catch { notice = Notice(error: error) }
        }
        if current == nil, !sending, !categoryMutationInProgress, !pending.isEmpty { advance() }
    }

    func chooseFiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "nzb") ?? .xml]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.begin { [weak self] result in
            if result == .OK { self?.receive(panel.urls) }
        }
    }

    func openSABnzbd() {
        guard let connection = try? ServerConnection(address: savedAddress, apiKey: savedKey),
              var url = URLComponents(url: connection.endpoint, resolvingAgainstBaseURL: false) else { return }
        var parts = url.path.split(separator: "/")
        if parts.last == "api" { parts.removeLast() }
        url.path = "/" + parts.joined(separator: "/") + (parts.isEmpty ? "" : "/")
        if let destination = url.url { NSWorkspace.shared.open(destination) }
    }

    func paste() {
        guard let text = NSPasteboard.general.string(forType: .string) else {
            notice = Notice(text: "In der Zwischenablage liegt kein Link.", isError: true)
            return
        }
        do {
            let link = try NZBLink(text)
            pending.append(.link(link))
            if current == nil, !sending, !categoryMutationInProgress { advance() }
        } catch { notice = Notice(error: error) }
    }

    private func advance() {
        task?.cancel()
        query = ""
        duplicateCategory = nil
        categoryToDelete = nil
        selectedPriority = .normal
        addPaused = false
        if !pending.isEmpty { current = pending.removeFirst() }
        if configured {
            screen = .downloads
            loadCategories()
        } else {
            screen = .settings
            notice = Notice(text: "Bitte zuerst die Verbindung zu SABnzbd einrichten.", isError: false)
        }
    }

    /// Refresh saved connection categories without blocking the app or changing local visibility choices.
    func refreshCategoriesAtStartup(launchedAtLogin: Bool = false,
                                    retryDelays: [Duration] = [.seconds(2), .seconds(5), .seconds(10)]) async {
        guard configured, !busy, !sending else { return }
        let revision = categoryLoadRevision
        let initialNotice = notice
        var delays = retryDelays.makeIterator()
        while !Task.isCancelled, revision == categoryLoadRevision, !busy, !sending {
            do {
                let connection = try ServerConnection(address: savedAddress, apiKey: savedKey)
                let result = try await client.categories(connection, loginProbe: launchedAtLogin)
                guard !Task.isCancelled, revision == categoryLoadRevision, !sending else { return }
                categories = result
                return
            } catch {
                guard !Task.isCancelled, revision == categoryLoadRevision else { return }
                if launchedAtLogin {
                    guard !busy, !sending, notice == initialNotice, !(error is CancellationError) else { return }
                    if let failure = error as? RelayError, case .retryableCategoryRead = failure,
                       let delay = delays.next() {
                        do { try await Task.sleep(for: delay) } catch { return }
                        continue
                    }
                }
                notice = Notice(error: error)
                return
            }
        }
    }

    func loadCategories() {
        guard !sending, !categoryMutationInProgress, !exporting, !exportPresented else { return }
        categoryLoadRevision += 1
        task?.cancel()
        busy = true
        progress = "Kategorien laden …"
        notice = nil
        categories = []
        categoryToDelete = nil
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
                notice = Notice(error: error)
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
            treasureMapsKey = treasureMapsKey.trimmingCharacters(in: .whitespacesAndNewlines)
            savedTreasureMapsKey = treasureMapsKey
            ninjaCentralKey = ninjaCentralKey.trimmingCharacters(in: .whitespacesAndNewlines)
            drunkenSlugKey = drunkenSlugKey.trimmingCharacters(in: .whitespacesAndNewlines)
            nzbFinderKey = nzbFinderKey.trimmingCharacters(in: .whitespacesAndNewlines)
            newzBayKey = newzBayKey.trimmingCharacters(in: .whitespacesAndNewlines)
            savedNewzBayKey = newzBayKey
            savedNinjaCentralKey = ninjaCentralKey
            savedDrunkenSlugKey = drunkenSlugKey
            savedNZBFinderKey = nzbFinderKey
            monitor.configure(connection)
            defaults.set(address, forKey: "serverAddress")
            defaults.set(key, forKey: "sabAPIKey")
            defaults.set(treasureMapsKey.isEmpty ? nil : treasureMapsKey, forKey: Self.treasureMapsPreference)
            defaults.set(newzBayKey.isEmpty ? nil : newzBayKey, forKey: Self.newzBayPreference)
            defaults.set(ninjaCentralKey.isEmpty ? nil : ninjaCentralKey, forKey: Self.ninjaCentralPreference)
            defaults.set(drunkenSlugKey.isEmpty ? nil : drunkenSlugKey, forKey: Self.drunkenSlugPreference)
            defaults.set(nzbFinderKey.isEmpty ? nil : nzbFinderKey, forKey: Self.nzbFinderPreference)
            configured = true
            screen = .downloads
            loadCategories()
        } catch { notice = Notice(error: error) }
    }

    func openCategories() {
        guard !busy, !sending, !exportPresented else { return }
        categoryToDelete = nil
        screen = .categories
        notice = nil
        if configured { loadCategories() }
    }

    func addCategory() {
        guard !busy, !exportPresented, configured else { return }
        let name = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let connection: ServerConnection
        do { connection = try ServerConnection(address: savedAddress, apiKey: savedKey) }
        catch { notice = Notice(error: error); return }
        categoryLoadRevision += 1
        task?.cancel()
        busy = true
        categoryMutationInProgress = true
        notice = nil
        progress = "Kategorie in SABnzbd anlegen …"
        task = Task {
            defer {
                busy = false
                categoryMutationInProgress = false
                if current == nil, !pending.isEmpty { advance() }
            }
            do {
                try await client.createCategory(name, connection: connection)
                newCategoryName = ""
                do {
                    categories = try await client.categories(connection)
                    notice = Notice(text: "Kategorie in SABnzbd angelegt.", isError: false)
                } catch {
                    notice = Notice(text: "Die Kategorie wurde in SABnzbd angelegt. Die Liste konnte nicht aktualisiert werden. Bitte Kategorien erneut laden.", isError: true)
                }
            } catch {
                notice = Notice(error: error)
            }
        }
    }

    func canDeleteCategory(_ name: String) -> Bool {
        !name.isEmpty && name != "*" && categories.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
    }

    func requestCategoryDeletion(_ name: String) {
        guard !busy, !exportPresented, configured, canDeleteCategory(name) else { return }
        categoryToDelete = name
    }

    func confirmCategoryDeletion(_ name: String) {
        guard !busy, !exportPresented, configured, canDeleteCategory(name) else { return }
        categoryToDelete = nil
        let connection: ServerConnection
        do { connection = try ServerConnection(address: savedAddress, apiKey: savedKey) }
        catch { notice = Notice(error: error); return }
        categoryLoadRevision += 1
        task?.cancel()
        busy = true
        categoryMutationInProgress = true
        notice = nil
        progress = "Kategorie in SABnzbd löschen …"
        task = Task {
            defer {
                busy = false
                categoryMutationInProgress = false
                if current == nil, !pending.isEmpty { advance() }
            }
            do {
                try await client.deleteCategory(name, connection: connection)
                categories.removeAll { $0.caseInsensitiveCompare(name) == .orderedSame }
                preferences.setVisible(true, category: name)
                preferences.setFavorite(false, category: name)
                persistCategoryPreferences()
                do {
                    categories = try await client.categories(connection)
                    notice = Notice(text: "Kategorie in SABnzbd gelöscht.", isError: false)
                } catch {
                    notice = Notice(text: "Die Kategorie wurde in SABnzbd gelöscht. Die Liste konnte nicht aktualisiert werden. Bitte Kategorien erneut laden.", isError: true)
                }
            } catch {
                notice = Notice(error: error)
            }
        }
    }

    func setVisible(_ visible: Bool, category: String) {
        preferences.setVisible(visible, category: category)
        if let data = try? JSONEncoder().encode(preferences) {
            defaults.set(data, forKey: "categoryPreferences")
        }
    }

    func setFavorite(_ enabled: Bool, category: String) {
        preferences.setFavorite(enabled, category: category)
        persistCategoryPreferences()
    }

    func moveFavorite(_ category: String, by offset: Int) {
        preferences.moveFavorite(category, by: offset)
        persistCategoryPreferences()
    }

    private func persistCategoryPreferences() {
        if let data = try? JSONEncoder().encode(preferences) { defaults.set(data, forKey: "categoryPreferences") }
    }

    func send(category: String) { performSend(category: category, allowDuplicate: false) }

    func confirmDuplicate() {
        guard let category = duplicateCategory else { return }
        duplicateCategory = nil
        performSend(category: category, allowDuplicate: true)
    }

    private func performSend(category: String, allowDuplicate: Bool) {
        guard !busy, !exportPresented, let submission = current else { return }
        let connection: ServerConnection
        do { connection = try ServerConnection(address: savedAddress, apiKey: savedKey) }
        catch { notice = Notice(error: error); return }
        let fingerprint = submission.fingerprint(server: connection.endpoint)
        if !allowDuplicate, submissionLedger.contains(fingerprint) {
            duplicateCategory = category
            return
        }
        let options = SendOptions(priority: selectedPriority, addPaused: addPaused)
        busy = true
        sending = true
        progress = "NZB suchen …"
        notice = nil
        task = Task {
            do {
                let ids: [String]
                switch submission {
                case .link(let link):
                    let resolver = NZBResolver(newznabClients: searchClients())
                    let download = try await resolver.resolve(link) { [self] provider in
                        await self.showSearchProvider(provider)
                    }
                    let file = try await resolver.fetchFile(download)
                    try Task.checkCancellation()
                    progress = "An SABnzbd senden …"
                    submissionLedger.record(fingerprint)
                    if let file {
                        ids = try await client.send(file, category: category, connection: connection, options: options,
                                                    title: link.title, password: link.password)
                    } else {
                        ids = try await client.send(link, download: download, category: category, connection: connection, options: options)
                    }
                case .file(let file):
                    progress = "An SABnzbd senden …"
                    submissionLedger.record(fingerprint)
                    ids = try await client.send(file, category: category, connection: connection, options: options)
                }
                monitor.trackSubmitted(ids)
                busy = false
                sending = false
                current = nil
                if pending.isEmpty { closeAfterSuccess?() }
                else { advance() }
            } catch {
                busy = false
                sending = false
                notice = Notice(error: error)
            }
        }
    }

    private func searchClients() -> [NewznabClient] {
        let keys: [(NewznabClient.Service, String)] = [
            (.treasureMaps, savedTreasureMapsKey),
            (.newzBay, savedNewzBayKey),
            (.ninjaCentral, savedNinjaCentralKey),
            (.drunkenSlug, savedDrunkenSlugKey),
            (.nzbFinder, savedNZBFinderKey)
        ]
        return keys.compactMap { service, key in
            key.isEmpty ? nil : NewznabClient(apiKey: key, service: service)
        }
    }

    func prepareExport() {
        guard !busy, !exportPresented, let submission = current else { return }
        busy = true
        exporting = true
        progress = "NZB-Datei vorbereiten …"
        notice = nil
        task = Task {
            defer {
                if !Task.isCancelled { exporting = false; busy = false }
            }
            do {
                let file: NZBFile
                switch submission {
                case .file(let imported): file = imported
                case .link(let link):
                    let resolver = exportResolver ?? NZBResolver(newznabClients: searchClients())
                    file = try await resolver.fileForExport(link) { [self] provider in
                        await self.showSearchProvider(provider)
                    }
                }
                try Task.checkCancellation()
                exportFile = file
                exportPresented = true
            } catch is CancellationError { }
            catch let error as URLError where error.code == .cancelled { }
            catch {
                guard !Task.isCancelled else { return }
                notice = Notice(error: error)
            }
        }
    }

    func completeExport(_ result: Result<URL, any Error>) {
        exportPresented = false
        exportFile = nil
        switch result {
        case .success: notice = Notice(text: "NZB-Datei gespeichert.", isError: false)
        case .failure(let error): notice = Notice(error: error)
        }
    }

    func cancelExport() {
        exportPresented = false
        exportFile = nil
    }

    func removePending(id: UUID) {
        pending.removeAll { $0.id == id }
    }

    func discardCurrent() {
        guard !sending, !categoryMutationInProgress, !exportPresented else { return }
        task?.cancel()
        exporting = false
        busy = false
        current = nil
        notice = nil
        if !pending.isEmpty { advance() }
    }

    private func showSearchProvider(_ provider: String) {
        progress = "NZB suchen: \(provider) …"
    }

    func refreshHandlerRegistration() {
        let handler = URL(string: "nzblnk://registration-check")
            .flatMap { NSWorkspace.shared.urlForApplication(toOpen: $0) }
        handlerRegistered = handler?.resolvingSymlinksInPath().path == Bundle.main.bundleURL.resolvingSymlinksInPath().path
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
        guard !sending, !categoryMutationInProgress, !exporting, !exportPresented else { return }
        categoryToDelete = nil
        address = savedAddress
        key = savedKey
        treasureMapsKey = savedTreasureMapsKey
        newzBayKey = savedNewzBayKey
        ninjaCentralKey = savedNinjaCentralKey
        drunkenSlugKey = savedDrunkenSlugKey
        nzbFinderKey = savedNZBFinderKey
        screen = .settings
        notice = nil
    }

    func categoryName(_ category: String) -> String { category == "*" || category.isEmpty ? L("Standard") : category }
}
