import AppKit
import Foundation
import RelayCore
import SwiftUI
import Testing
@testable import NZBRelay

@Test(arguments: [
    ("Fixture.S02E01E02.WEB-DL", CategoryRecognition.Kind.series),
    ("Fixture.S02.BluRay", .series),
    ("Fixture.2x103.HDTV", .series),
    ("Fixture.XBOX.Series.X.BluRay", .games),
    ("Fixture.S02.Switch-TENOKE", .games),
    ("Fixture.Early.Access", .games),
    ("Fixture-RUNE", .games),
    ("Fixture.2026.UHD.Blu-Ray", .movies),
    ("Fixture.2026.1080p.WEBRip", .movies),
    ("Fixture.2026.1080p.REMUX", .movies),
    ("Fixture.1080p", .misc),
    ("Fixture.Crossweb", .misc),
    ("Fixture.PS50", .misc)
])
func detectsReleaseTypesLikeUserscript(title: String, kind: CategoryRecognition.Kind) {
    #expect(CategoryRecognition.Kind.detect(in: title) == kind)
}

@Test(arguments: [
    ("Fixture 2099 2026 Complete German DL EAC3 2160p DV HDR10Plus AMZN WEB H265", CategoryRecognition.Kind.series),
    ("blade.runner.2099.2026.complete.amzn.web", .series),
    ("Fixture.Xbox_complete", .series),
    ("Fixture.2026.Complete.AMZN.WEB", .series),
    ("Blade.Runner.2049.2017.BluRay", .movies),
    ("Fixture.Incomplete.WEB", .movies),
    ("Fixture.Completed.WEB", .movies)
])
func completeAsAWholeWordTakesPrecedenceOverOtherMarkers(title: String, kind: CategoryRecognition.Kind) {
    #expect(CategoryRecognition.Kind.detect(in: title) == kind)
}

@Test func categoryRecognitionUsesFirstAvailableTitleRuleAndOnlyFallsBackToMiscForOtherTitles() {
    var recognition = CategoryRecognition()
    recognition[.series] = "TV"
    recognition[.misc] = "*"
    recognition.rules = [
        .init(pattern: " _ ", category: "*"),
        .init(pattern: "example_show", category: "Archive"),
        .init(pattern: "EXAMPLE SHOW", category: "Special"),
        .init(pattern: "example", category: "*")
    ]
    #expect(recognition.suggestion(for: "Example.Show.S01E02", availableCategories: ["Special", "TV", "*"]) == "Special")
    #expect(recognition.suggestion(for: "Other.Show.S01E02", availableCategories: ["TV", "*"]) == "TV")
    #expect(recognition.suggestion(for: "Other.Show.S01E02", availableCategories: ["*"]) == nil)
    #expect(recognition.suggestion(for: "Other.Title", availableCategories: ["*"]) == "*")
}

private actor RecognitionTransport: HTTPTransport {
    let uploadSucceeds: Bool
    private(set) var submittedCategories: [String] = []

    init(uploadSucceeds: Bool = true) { self.uploadSucceeds = uploadSucceeds }

    func perform(_ request: URLRequest) async throws -> HTTPResult {
        let success = HTTPResult(data: Data(#"{"status":true,"nzo_ids":["job-test"]}"#.utf8), status: 200)
        if request.value(forHTTPHeaderField: "Content-Type")?.contains("multipart") == true {
            let body = try #require(request.httpBody.flatMap { String(data: $0, encoding: .utf8) })
            let categoryField = try #require(body.components(separatedBy: "name=\"cat\"\r\n\r\n").dropFirst().first)
            submittedCategories.append(String(categoryField.prefix { !$0.isNewline }))
            if !uploadSucceeds { throw URLError(.timedOut) }
            return success
        }
        var form = URLComponents()
        form.percentEncodedQuery = request.httpBody.flatMap { String(data: $0, encoding: .utf8) }
        if form.queryItems?.contains(URLQueryItem(name: "mode", value: "addurl")) == true {
            let category = try #require(form.queryItems?.first { $0.name == "cat" }?.value)
            submittedCategories.append(category)
            return success
        }
        return HTTPResult(data: Data(#"{"categories":["*","TV","Movies"]}"#.utf8), status: 200)
    }
}

private struct RecognitionSearchProvider: NZBSearchProvider {
    let name = "Synthetic"

    func resolve(_ link: NZBLink) async throws -> URL {
        try #require(URL(string: "https://nzbindex.com/api/download/synthetic.nzb"))
    }
}

@MainActor @Test func recognizedNZBlnkIsSentWhileNextUnmatchedLinkWaitsForSelection() async throws {
    let domain = "NZBPort.Recognition." + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: domain))
    defer { defaults.removePersistentDomain(forName: domain) }
    defaults.set("https://sab.example.invalid/api", forKey: "serverAddress")
    defaults.set("synthetic-test-key", forKey: "sabAPIKey")
    let transport = RecognitionTransport()
    let model = AppModel(defaults: defaults, client: SABClient(transport: transport),
                         resolverOverride: NZBResolver(providers: [RecognitionSearchProvider()]))
    model.categoryRecognition.automaticallySends = true
    model.categoryRecognition[.movies] = "Movies"
    model.categoryRecognition.rules = [.init(pattern: "fixture movie", category: "TV")]
    let match = try #require(URL(string: "nzblnk:?h=first&t=Fixture.Movie.BluRay"))
    let unmatched = try #require(URL(string: "nzblnk:?h=second&t=Fixture.Other"))

    model.receive([match, unmatched])
    await model.task?.value
    await model.task?.value
    await model.task?.value
    #expect(await transport.submittedCategories == ["TV"])
    #expect(model.current?.title == "Fixture.Other" && model.screen == .downloads && !model.busy)
}

@MainActor @Test(arguments: [true, false])
func recognizedNZBIsSentOnceAndFallsBackToSelectionAfterError(uploadSucceeds: Bool) async throws {
    let domain = "NZBPort.Recognition." + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: domain))
    defer { defaults.removePersistentDomain(forName: domain) }
    defaults.set("https://sab.example.invalid/api", forKey: "serverAddress")
    defaults.set("synthetic-test-key", forKey: "sabAPIKey")
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("Fixture.S02E01.WEB-DL.nzb")
    let data = Data("<nzb/>".utf8)
    try data.write(to: file)
    let transport = RecognitionTransport(uploadSucceeds: uploadSucceeds)
    let model = AppModel(defaults: defaults, client: SABClient(transport: transport))
    model.categoryRecognition[.series] = "TV"
    model.categoryRecognition.automaticallySends = true
    #expect(AppModel(defaults: defaults, client: SABClient(transport: transport)).categoryRecognition == model.categoryRecognition)

    model.receive([file])
    await model.task?.value
    await model.task?.value
    #expect(await transport.submittedCategories == ["TV"])
    #expect(!model.automaticallySending)
    if uploadSucceeds {
        #expect(model.current == nil)
        #expect(model.automaticSubmissionNotice?.text.contains("TV") == true)
        model.receive([file])
        await model.task?.value
    } else {
        #expect(model.current?.title == "Fixture.S02E01.WEB-DL")
        #expect(model.notice?.isError == true)
        #expect(model.automaticSubmissionNotice == nil)
        model.loadCategories()
        await model.task?.value
        #expect(model.visibleCategories.first == "TV")
        #expect(model.duplicateCategory == nil)
        model.send(category: "TV")
    }
    #expect(model.duplicateCategory == "TV")
    #expect(await transport.submittedCategories == ["TV"])
}

@MainActor @Test func watchedDownloadUsesTheSameAutomaticSubmissionPath() async throws {
    let domain = "NZBPort.Recognition." + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: domain))
    defer { defaults.removePersistentDomain(forName: domain) }
    defaults.set("https://sab.example.invalid/api", forKey: "serverAddress")
    defaults.set("synthetic-test-key", forKey: "sabAPIKey")
    let transport = RecognitionTransport()
    let model = AppModel(defaults: defaults, client: SABClient(transport: transport))
    model.categoryRecognition.automaticallySends = true
    model.categoryRecognition[.series] = "TV"
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let file = try NZBFile(data: Data("<nzb/>".utf8), filename: "Fixture.Complete.WEB.nzb")
    let source = WatchedNZBSource(folder: folder, url: folder.appendingPathComponent(file.title + ".nzb"), device: 0, inode: 0)

    model.receiveDownloadedFiles([WatchedNZBFile(file: file, source: source)])
    await model.task?.value
    await model.task?.value
    #expect(await transport.submittedCategories == ["TV"])
    #expect(model.automaticSubmissionNotice?.text.contains("TV") == true)
}

@MainActor @Test func unmatchedOrHiddenCategoriesLeaveNZBlnksInManualSelection() async throws {
    let domain = "NZBPort.Recognition." + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: domain))
    defer { defaults.removePersistentDomain(forName: domain) }
    defaults.set("https://sab.example.invalid/api", forKey: "serverAddress")
    defaults.set("synthetic-test-key", forKey: "sabAPIKey")
    let transport = RecognitionTransport()
    let model = AppModel(defaults: defaults, client: SABClient(transport: transport))
    model.categoryRecognition.automaticallySends = true
    model.categoryRecognition[.series] = "TV"
    model.setVisible(false, category: "tv")

    for title in ["Fixture.S02E01", "Fixture.Other.Title"] {
        model.receive([try #require(URL(string: "nzblnk:?h=fixture&t=\(title)"))])
        await model.task?.value
        #expect(model.current?.title == title)
        #expect(model.screen == .downloads && !model.busy && !model.sending)
        #expect(model.suggestedCategory == nil)
        #expect(model.visibleCategories == ["*", "Movies"])
        model.discardCurrent()
    }
    #expect(await transport.submittedCategories.isEmpty)
}

@MainActor @Test func renderCategoryRecognitionControls() throws {
    guard let path = ProcessInfo.processInfo.environment["NZBPORT_RECOGNITION_VERIFICATION_DIR"] else { return }
    let directory = URL(fileURLWithPath: path, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var recognition = CategoryRecognition()
    recognition.automaticallySends = true
    recognition[.series] = "TV"
    recognition[.games] = "Games"
    recognition[.movies] = "Movies"
    for scheme in [ColorScheme.light, .dark] {
        let view = VStack(alignment: .leading, spacing: 16) {
            CategoryRecognitionView(recognition: .constant(recognition), categories: ["*", "TV", "Games", "Movies"]) {
                $0 == "*" ? L("Standard") : $0
            }
            CategorySendButton(name: "TV", recommended: true) {}
                .frame(maxWidth: .infinity)
        }
        .padding(20)
        .frame(width: 470)
        .background(scheme == .light ? Color(white: 0.95) : Color(white: 0.12))
        .environment(\.colorScheme, scheme)
        try writeSnapshot(of: view, scheme: scheme, to: directory)
    }
}

@MainActor @Test func renderSABnzbdFeedback() throws {
    guard let path = ProcessInfo.processInfo.environment["NZBPORT_SAB_FEEDBACK_VERIFICATION_DIR"] else { return }
    let directory = URL(fileURLWithPath: path, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    for scheme in [ColorScheme.light, .dark] {
        let view = VStack(alignment: .leading, spacing: 16) {
            ConnectionStatusView(status: .unchecked)
            ConnectionStatusView(status: .checking)
            ConnectionStatusView(status: .connected(categoryCount: 0))
            ConnectionStatusView(status: .failed(RelayError.message("Enter the complete SABnzbd API key.").localizedDescription))
            SubmissionConfirmationView(notice: Notice(text: "An SABnzbd gesendet · \("Serien")", isError: false))
        }
        .padding(20)
        .frame(width: 470)
        .background(scheme == .light ? Color(white: 0.95) : Color(white: 0.12))
        .environment(\.colorScheme, scheme)
        try writeSnapshot(of: view, scheme: scheme, to: directory)
    }
}

@MainActor @Test func renderIndexerSettings() throws {
    guard let path = ProcessInfo.processInfo.environment["NZBPORT_INDEXERS_VERIFICATION_DIR"] else { return }
    let directory = URL(fileURLWithPath: path, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let name = "NZBPort.IndexerRendering.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    let model = AppModel(defaults: defaults)
    model.indexerPreferences.move(.newzBay, by: -4)
    model.indexerPreferences.setEnabled(false, for: .nzbKing)
    for scheme in [ColorScheme.light, .dark] {
        let view = IndexerSettingsSection(model: model)
            .padding(20)
            .frame(width: 460)
            .background(scheme == .light ? Color(white: 0.95) : Color(white: 0.12))
            .environment(\.colorScheme, scheme)
        try writeSnapshot(of: view, scheme: scheme, to: directory)
    }
}

@MainActor private func writeSnapshot(of view: some View, scheme: ColorScheme, to directory: URL) throws {
    let host = NSHostingView(rootView: view)
    let window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: true)
    window.isReleasedWhenClosed = false
    window.appearance = NSAppearance(named: scheme == .light ? .aqua : .darkAqua)
    window.contentView = host
    window.setContentSize(host.fittingSize)
    host.layoutSubtreeIfNeeded()
    let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
    host.cacheDisplay(in: host.bounds, to: bitmap)
    let png = try #require(bitmap.representation(using: .png, properties: [:]))
    try png.write(to: directory.appendingPathComponent(scheme == .light ? "light.png" : "dark.png"))
}
