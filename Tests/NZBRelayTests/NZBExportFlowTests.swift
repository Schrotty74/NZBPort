import Foundation
import Testing
import RelayCore
@testable import NZBRelay

private actor ExportFlowTransport: HTTPTransport {
    private(set) var requests = 0
    func perform(_ request: URLRequest) async throws -> HTTPResult {
        requests += 1
        if request.url?.path == "/api/search" {
            return HTTPResult(data: Data(#"{"data":{"content":[{"id":"synthetic"}]},"error":false}"#.utf8), status: 200)
        }
        return HTTPResult(data: Data("<nzb><file/></nzb>".utf8), status: 200)
    }
}

private struct FailingExportProvider: NZBSearchProvider {
    let name = "Synthetic"
    func resolve(_ link: NZBLink) async throws -> URL { throw URLError(.cannotConnectToHost) }
}

@MainActor @Test func exportWithoutSABKeepsSubmissionAndDoesNotSend() async throws {
    let domain = "NZBPort.Tests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: domain)!
    defer { defaults.removePersistentDomain(forName: domain) }
    let search = ExportFlowTransport(), sab = ExportFlowTransport()
    let model = AppModel(defaults: defaults, client: SABClient(transport: sab), resolverOverride: NZBResolver(transport: search))
    model.receive([URL(string: "nzblnk:?h=synthetic&t=Release")!])
    let id = model.current?.id
    #expect(!model.configured && model.screen == .settings)
    model.prepareExport()
    await model.task?.value
    #expect(model.exportPresented && !model.busy && !model.exporting)
    #expect(model.exportFile?.data == Data("<nzb><file/></nzb>".utf8))
    #expect(model.current?.id == id)
    #expect(await sab.requests == 0)
    model.completeExport(.success(URL(fileURLWithPath: "/synthetic/Release.nzb")))
    #expect(model.exportFile == nil && !model.exportPresented)
    #expect(model.current?.id == id && model.notice?.isError == false)
}

@MainActor @Test func cancelOrFailedSaveKeepsCurrentSubmission() async throws {
    let domain = "NZBPort.Tests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: domain)!
    defer { defaults.removePersistentDomain(forName: domain) }
    let model = AppModel(defaults: defaults, resolverOverride: NZBResolver(transport: ExportFlowTransport()))
    model.receive([URL(string: "nzblnk:?h=synthetic&t=Release")!])
    let id = model.current?.id
    model.prepareExport()
    await model.task?.value
    model.cancelExport()
    #expect(model.current?.id == id && model.exportFile == nil && model.notice == nil)
    model.prepareExport()
    await model.task?.value
    model.completeExport(.failure(CocoaError(.fileWriteNoPermission)))
    #expect(model.current?.id == id && !model.exportPresented && model.exportFile == nil)
    #expect(model.notice?.isError == true)
}

@MainActor @Test func failedExportSearchKeepsSubmissionAndReportsError() async {
    let domain = "NZBPort.Tests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: domain)!
    defer { defaults.removePersistentDomain(forName: domain) }
    let model = AppModel(defaults: defaults, resolverOverride: NZBResolver(providers: [FailingExportProvider()]))
    model.receive([URL(string: "nzblnk:?h=synthetic&t=Release")!])
    let id = model.current?.id
    model.prepareExport()
    await model.task?.value
    #expect(!model.exportPresented && !model.busy && !model.exporting && model.exportFile == nil)
    #expect(model.current?.id == id && model.notice?.isError == true)
}

@MainActor @Test func exportsImportedFileWithoutSearchOrSAB() async throws {
    let domain = "NZBPort.Tests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: domain)!
    defer { defaults.removePersistentDomain(forName: domain) }
    let fixture = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".nzb")
    let bytes = Data("<nzb><head><meta type=\"password\">synthetic</meta></head><file/></nzb>".utf8)
    try bytes.write(to: fixture)
    defer { try? FileManager.default.removeItem(at: fixture) }
    let sab = ExportFlowTransport()
    let model = AppModel(defaults: defaults, client: SABClient(transport: sab), resolverOverride: NZBResolver(providers: [FailingExportProvider()]))
    model.receive([fixture])
    let id = model.current?.id
    model.prepareExport()
    await model.task?.value
    #expect(model.exportFile?.data == bytes && model.exportPresented)
    #expect(await sab.requests == 0)
    model.discardCurrent()
    #expect(model.current?.id == id)
    model.cancelExport()
}
