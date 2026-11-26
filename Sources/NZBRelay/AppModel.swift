import AppKit
import UniformTypeIdentifiers
import Observation
import RelayCore

enum Screen { case downloads, settings, categories, overview, updates }
enum SABConnectionStatus: Equatable {
    case unchecked, checking, connected(categoryCount: Int), failed(String)
}
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
    private static let videothekPreference = "videothekAPIKey"

    var screen: Screen = .downloads
    let appearanceSettings: AppearanceSettings
    let languageSettings: LanguageSettings
    let loginItemSettings = LoginItemSettings()
    let downloadFolder: DownloadFolderMonitor
    let updateSettings: UpdateSettings
    let monitor: DownloadMonitor
    var selectedPriority = SABPriority.normal
    var addPaused = false
    var duplicateCategory: String?
    private var submissionLedger = SubmissionLedger()
    var address = SettingsBackup.defaultServerAddress {
        didSet { if address != oldValue { invalidateConnectionTest() } }
    }
    var key = "" {
        didSet { if key != oldValue { invalidateConnectionTest() } }
    }
    private(set) var connectionStatus = SABConnectionStatus.unchecked
    private(set) var automaticSubmissionNotice: Notice?
    @ObservationIgnored private(set) var connectionTestTask: Task<Void, Never>?
    @ObservationIgnored private var confirmationTask: Task<Void, Never>?
    var treasureMapsKey = ""
    var newzBayKey = ""
    var ninjaCentralKey = ""
    var drunkenSlugKey = ""
    var nzbFinderKey = ""
    var videothekKey = ""
    var newCategoryName = ""
    var categoryToDelete: String?
    private(set) var categoryMutationInProgress = false
    private(set) var categories: [String] = []
    private(set) var preferences = CategoryPreferences()
    var indexerPreferences = IndexerPreferences() {
        didSet {
            if let data = try? JSONEncoder().encode(indexerPreferences) {
                defaults.set(data, forKey: "indexerPreferences")
            }
        }
    }
    private(set) var current: DownloadSubmission?
    private(set) var pending: [DownloadSubmission] = []
    private(set) var busy = false
    private(set) var sending = false
    private(set) var automaticallySending = false
    private(set) var exporting = false
    private(set) var exportFile: NZBFile?
    var exportPresented = false
    private(set) var progress: String.LocalizationValue = ""
    var notice: Notice?
    var query = ""
    private(set) var configured = false
    private(set) var handlerRegistered = false
    private(set) var registeringHandler = false
    private(set) var applyingSettings = false
    private let client: SABClient
    private let resolverOverride: NZBResolver?
    @ObservationIgnored private let defaults: UserDefaults
    private var categoryLoadRevision = 0
    private var automaticCategoryPending = false
    private var savedAddress = ""
    private var savedKey = ""
    private var savedTreasureMapsKey = ""
    private var savedNewzBayKey = ""
    private var savedNinjaCentralKey = ""
    private var savedDrunkenSlugKey = ""
    private var savedNZBFinderKey = ""
    private var savedVideothekKey = ""
    @ObservationIgnored private(set) var task: Task<Void, Never>?
    @ObservationIgnored var closeAfterSuccess: (() -> Void)?

    init(defaults: UserDefaults = .standard, client: SABClient = SABClient(), resolverOverride: NZBResolver? = nil) {
        self.defaults = defaults
        self.client = client
        self.resolverOverride = resolverOverride
        downloadFolder = DownloadFolderMonitor(defaults: defaults)
        updateSettings = UpdateSettings(defaults: defaults)
        monitor = DownloadMonitor(client: client, defaults: defaults)
        appearanceSettings = AppearanceSettings(defaults: defaults)
        languageSettings = LanguageSettings(defaults: defaults)
        address = defaults.string(forKey: "serverAddress") ?? address
        if let data = defaults.data(forKey: "categoryPreferences"),
           let decoded = try? JSONDecoder().decode(CategoryPreferences.self, from: data) {
            preferences = decoded
        }
        if let data = defaults.data(forKey: "indexerPreferences"),
           let decoded = try? JSONDecoder().decode(IndexerPreferences.self, from: data) {
            indexerPreferences = decoded
        }
        key = defaults.string(forKey: "sabAPIKey") ?? ""
        treasureMapsKey = defaults.string(forKey: Self.treasureMapsPreference) ?? ""
        newzBayKey = defaults.string(forKey: Self.newzBayPreference) ?? ""
        ninjaCentralKey = defaults.string(forKey: Self.ninjaCentralPreference) ?? ""
        drunkenSlugKey = defaults.string(forKey: Self.drunkenSlugPreference) ?? ""
        nzbFinderKey = defaults.string(forKey: Self.nzbFinderPreference) ?? ""
        videothekKey = defaults.string(forKey: Self.videothekPreference) ?? ""
        configured = (try? ServerConnection(address: address, apiKey: key)) != nil
        savedAddress = address
        savedKey = key
        savedTreasureMapsKey = treasureMapsKey
        savedNewzBayKey = newzBayKey
        savedNinjaCentralKey = ninjaCentralKey
        savedDrunkenSlugKey = drunkenSlugKey
        savedNZBFinderKey = nzbFinderKey
        savedVideothekKey = videothekKey
        if !configured { screen = .settings }
        monitor.configure(try? ServerConnection(address: savedAddress, apiKey: savedKey))
    }

    var visibleCategories: [String] {
        var visible = preferences.visible(in: categories).filter {
            query.isEmpty || categoryName($0).localizedCaseInsensitiveContains(query)
        }
        if let suggestedCategory, let index = visible.firstIndex(of: suggestedCategory), index > 0 {
            visible.insert(visible.remove(at: index), at: 0)
        }
        return visible
    }
    var suggestedCategory: String? {
        guard let current else { return nil }
        return categoryRecognition.suggestion(for: current.title, availableCategories: preferences.visible(in: categories))
    }
    var categoryRecognition: CategoryRecognition {
        get { preferences.recognition }
        set {
            preferences.recognition = newValue
            persistCategoryPreferences()
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
                try enqueue(submission)
            } catch { notice = Notice(error: error) }
        }
        advanceIfReady()
    }

    private func enqueue(_ submission: DownloadSubmission) throws {
        guard pending.count < 50 else { throw RelayError.message("Too many pending downloads.") }
        guard pending.reduce(current?.byteCount ?? 0, { $0 + $1.byteCount }) + submission.byteCount <= 64 * 1024 * 1024 else {
            throw RelayError.message("Pending NZB files exceed 64 MiB.")
        }
        pending.append(submission)
    }

    private func advanceIfReady() {
        if current == nil, !sending, !categoryMutationInProgress, !applyingSettings, !pending.isEmpty { advance() }
    }

    func receiveDownloadedFiles(_ files: [WatchedNZBFile]) {
        for file in files {
            do { try enqueue(.file(file.file, source: file.source)) }
            catch { notice = Notice(error: error); break }
        }
        advanceIfReady()
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
        automaticCategoryPending = categoryRecognition.automaticallySends
        if configured {
            screen = .downloads
            loadCategories(forIncomingSubmission: true)
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

    func checkConnection() {
        connectionTestTask?.cancel()
        connectionStatus = .checking
        let address = address
        let key = key
        connectionTestTask = Task {
            do {
                try Task.checkCancellation()
                let connection = try ServerConnection(address: address, apiKey: key)
                let categories = try await client.categories(connection)
                try Task.checkCancellation()
                connectionStatus = .connected(categoryCount: categories.count)
            } catch {
                guard !Task.isCancelled else { return }
                connectionStatus = .failed(error.localizedDescription)
            }
        }
    }

    private func invalidateConnectionTest() {
        connectionTestTask?.cancel()
        connectionTestTask = nil
        connectionStatus = .unchecked
    }

    func loadCategories(forIncomingSubmission: Bool = false) {
        guard !sending, !categoryMutationInProgress, !exporting, !exportPresented else { return }
        categoryLoadRevision += 1
        task?.cancel()
        busy = true
        progress = "Kategorien laden …"
        notice = nil
        categories = []
        categoryToDelete = nil
        let shouldSend = forIncomingSubmission && automaticCategoryPending && screen == .downloads
        if shouldSend { automaticCategoryPending = false }
        task = Task {
            do {
                let connection = try ServerConnection(address: savedAddress, apiKey: savedKey)
                let result = try await client.categories(connection)
                try Task.checkCancellation()
                categories = result
            } catch is CancellationError { }
            catch let error as URLError where error.code == .cancelled { }
            catch {
                guard !Task.isCancelled else { return }
                notice = Notice(error: error)
            }
            guard !Task.isCancelled else { return }
            busy = false
            if shouldSend, screen == .downloads, categoryRecognition.automaticallySends, let suggestedCategory {
                performSend(category: suggestedCategory, allowDuplicate: false, automatic: true)
            }
        }
    }

    func save() {
        guard !busy, !applyingSettings else { return }
        do {
            let connection = try ServerConnection(address: address, apiKey: key)
            persistConnectionSettings(
                .init(address: address, apiKey: key, treasureMaps: treasureMapsKey, newzBay: newzBayKey,
                      ninjaCentral: ninjaCentralKey, drunkenSlug: drunkenSlugKey,
                      nzbFinder: nzbFinderKey, videothek: videothekKey),
                server: connection
            )
            screen = .downloads
            loadCategories(forIncomingSubmission: true)
        } catch { notice = Notice(error: error) }
    }

    private func persistConnectionSettings(_ settings: SettingsBackup.Connection, server: ServerConnection?) {
        address = server?.endpoint.absoluteString ?? settings.address.trimmingCharacters(in: .whitespacesAndNewlines)
        key = server?.apiKey ?? ""
        treasureMapsKey = settings.treasureMaps.trimmingCharacters(in: .whitespacesAndNewlines)
        newzBayKey = settings.newzBay.trimmingCharacters(in: .whitespacesAndNewlines)
        ninjaCentralKey = settings.ninjaCentral.trimmingCharacters(in: .whitespacesAndNewlines)
        drunkenSlugKey = settings.drunkenSlug.trimmingCharacters(in: .whitespacesAndNewlines)
        nzbFinderKey = settings.nzbFinder.trimmingCharacters(in: .whitespacesAndNewlines)
        videothekKey = settings.videothek.trimmingCharacters(in: .whitespacesAndNewlines)
        savedAddress = address
        savedKey = key
        savedTreasureMapsKey = treasureMapsKey
        savedNewzBayKey = newzBayKey
        savedNinjaCentralKey = ninjaCentralKey
        savedDrunkenSlugKey = drunkenSlugKey
        savedNZBFinderKey = nzbFinderKey
        savedVideothekKey = videothekKey
        defaults.set(address, forKey: "serverAddress")
        defaults.set(key, forKey: "sabAPIKey")
        for (name, value) in [
            (Self.treasureMapsPreference, treasureMapsKey), (Self.newzBayPreference, newzBayKey),
            (Self.ninjaCentralPreference, ninjaCentralKey), (Self.drunkenSlugPreference, drunkenSlugKey),
            (Self.nzbFinderPreference, nzbFinderKey), (Self.videothekPreference, videothekKey)
        ] {
            defaults.set(value.isEmpty ? nil : value, forKey: name)
        }
        configured = server != nil
        monitor.configure(server)
    }

    var canManageSettings: Bool { !busy && !sending && !exportPresented && !applyingSettings }

    func settingsBackup() -> SettingsBackup {
        SettingsBackup(
            connection: .init(address: savedAddress, apiKey: savedKey, treasureMaps: savedTreasureMapsKey,
                              newzBay: savedNewzBayKey, ninjaCentral: savedNinjaCentralKey,
                              drunkenSlug: savedDrunkenSlugKey, nzbFinder: savedNZBFinderKey,
                              videothek: savedVideothekKey),
            categories: preferences, language: languageSettings.selection, appearance: appearanceSettings.mode,
            colorTheme: appearanceSettings.theme, backgroundStyle: appearanceSettings.background,
            includeTestUpdates: updateSettings.includePrereleases, downloadNotifications: monitor.notificationsEnabled,
            launchAtLogin: loginItemSettings.requested, watchedDownloadFolder: downloadFolder.backupPath,
            indexers: indexerPreferences
        )
    }

    func applySettingsBackup(_ backup: SettingsBackup) async throws -> [String] {
        guard canManageSettings else {
            throw RelayError.message("Wait until the current operation finishes before changing settings.")
        }
        let server = try backup.connection.validatedServer()
        applyingSettings = true
        defer {
            applyingSettings = false
            if current == nil, !pending.isEmpty { advanceIfReady() }
            else if configured { loadCategories() }
        }
        persistConnectionSettings(backup.connection, server: server)
        preferences = backup.categories
        persistCategoryPreferences()
        indexerPreferences = backup.indexers ?? .init()
        categories = []
        query = ""
        duplicateCategory = nil
        categoryToDelete = nil
        screen = configured ? .downloads : .settings
        appearanceSettings.mode = backup.appearance
        appearanceSettings.theme = backup.colorTheme
        appearanceSettings.background = backup.backgroundStyle
        languageSettings.selection = backup.language
        updateSettings.includePrereleases = backup.includeTestUpdates
        var followUp: [String] = []
        if downloadFolder.restoreBackupPath(backup.watchedDownloadFolder) {
            followUp.append(L("Wähle den Downloadordner erneut aus, um die Überwachung zu starten."))
        }
        loginItemSettings.setEnabled(backup.launchAtLogin)
        if loginItemSettings.requested != backup.launchAtLogin || loginItemSettings.needsApproval {
            followUp.append(L("Prüfe den Autostart in den macOS-Anmeldeobjekten."))
        }
        if monitor.notificationsEnabled != backup.downloadNotifications {
            await monitor.setNotifications(backup.downloadNotifications)
        }
        if monitor.notificationsEnabled != backup.downloadNotifications {
            followUp.append(L("Prüfe die Mitteilungen für NZBPort in den macOS-Einstellungen."))
        }
        return followUp
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

    func reorderFavorites(_ visibleFavorites: [String], moving sources: [String], before destination: String?) {
        preferences.reorderFavorites(visibleFavorites, moving: sources, before: destination)
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

    private func performSend(category: String, allowDuplicate: Bool, automatic: Bool = false) {
        guard !busy, !exportPresented, !applyingSettings, let submission = current else { return }
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
        automaticallySending = automatic
        progress = "NZB suchen …"
        notice = nil
        task = Task {
            do {
                let ids: [String]
                var cleanupFailed = false
                switch submission {
                case .link(let link):
                    let resolver = searchResolver()
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
                case .file(let file, let source):
                    progress = "An SABnzbd senden …"
                    submissionLedger.record(fingerprint)
                    ids = try await client.send(file, category: category, connection: connection, options: options)
                    if let source {
                        do {
                            _ = try await Task.detached(priority: .utility) {
                                try source.moveToTrash(ifUnchanged: file.data)
                            }.value
                        } catch { cleanupFailed = true }
                    }
                }
                monitor.trackSubmitted(ids)
                busy = false
                sending = false
                automaticallySending = false
                current = nil
                if automatic { confirmAutomaticSubmission(to: category, closeWhenIdle: !cleanupFailed && pending.isEmpty) }
                if !pending.isEmpty { advance() }
                else if !automatic, !cleanupFailed { closeAfterSuccess?() }
                if cleanupFailed {
                    notice = Notice(text: "An SABnzbd gesendet. Die NZB-Datei konnte nicht in den Papierkorb gelegt werden.", isError: true)
                }
            } catch {
                busy = false
                sending = false
                automaticallySending = false
                notice = Notice(error: error)
            }
        }
    }

    private func confirmAutomaticSubmission(to category: String, closeWhenIdle: Bool) {
        confirmationTask?.cancel()
        automaticSubmissionNotice = Notice(text: "An SABnzbd gesendet · \(categoryName(category))", isError: false)
        confirmationTask = Task {
            do { try await Task.sleep(for: .seconds(3)) }
            catch { return }
            automaticSubmissionNotice = nil
            if closeWhenIdle, current == nil, pending.isEmpty, screen == .downloads, !busy {
                closeAfterSuccess?()
            }
        }
    }

    private func searchClients() -> [NewznabClient] {
        let keys: [(NewznabClient.Service, String)] = [
            (.treasureMaps, savedTreasureMapsKey),
            (.newzBay, savedNewzBayKey),
            (.ninjaCentral, savedNinjaCentralKey),
            (.drunkenSlug, savedDrunkenSlugKey),
            (.nzbFinder, savedNZBFinderKey),
            (.videothek, savedVideothekKey)
        ]
        return keys.compactMap { service, key in
            key.isEmpty ? nil : NewznabClient(apiKey: key, service: service)
        }
    }

    private func searchResolver() -> NZBResolver {
        resolverOverride ?? NZBResolver(newznabClients: searchClients(), preferences: indexerPreferences)
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
                case .file(let imported, _): file = imported
                case .link(let link):
                    let resolver = searchResolver()
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
        automaticCategoryPending = false
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
        videothekKey = savedVideothekKey
        screen = .settings
        notice = nil
        if configured, connectionStatus == .unchecked { checkConnection() }
    }

    func categoryName(_ category: String) -> String { category == "*" || category.isEmpty ? L("Standard") : category }
}
