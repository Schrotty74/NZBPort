import Foundation
import Testing
@testable import RelayCore

private actor ExportTransport: HTTPTransport {
    private var results: [HTTPResult]
    private var requests: [URLRequest] = []
    init(_ results: [HTTPResult]) { self.results = results }
    func perform(_ request: URLRequest) async throws -> HTTPResult {
        requests.append(request)
        guard !results.isEmpty else { throw URLError(.badServerResponse) }
        return results.removeFirst()
    }
    func captured() -> [URLRequest] { requests }
}

private func indexResult() -> HTTPResult {
    HTTPResult(data: Data(#"{"data":{"content":[{"id":"fixture-1"}]},"error":false}"#.utf8), status: 200)
}

private func passwordMetadata(in data: Data) throws -> [String] {
    let document = try XMLDocument(data: data, options: [.nodeLoadExternalEntitiesNever])
    func values(_ node: XMLNode) -> [String] {
        let own: [String]
        if let element = node as? XMLElement, element.localName == "meta",
           element.attribute(forName: "type")?.stringValue == "password" {
            own = [element.stringValue ?? ""]
        } else { own = [] }
        return own + (node.children ?? []).flatMap(values)
    }
    return document.rootElement().map(values) ?? []
}

@Test func exportsPublicNZBWithSafeTitleAndPasswordFilename() async throws {
    let transport = ExportTransport([indexResult(), HTTPResult(data: Data("<nzb><file/></nzb>".utf8), status: 200)])
    let link = try NZBLink("nzblnk:?h=fixture&t=Show%2FEpisode&p=archive%2Fkey%26%22")
    let file = try await NZBResolver(transport: transport).fileForExport(link)
    #expect(file.title == "Show_Episode")
    #expect(try passwordMetadata(in: file.data) == ["archive/key&\""])
    #expect(await transport.captured().last?.url?.absoluteString == "https://nzbindex.com/api/download/fixture-1.nzb")
}

@Test func rejectsFailedPublicDownloadHTTPStatus() async throws {
    let transport = ExportTransport([indexResult(), HTTPResult(data: Data("<nzb/>".utf8), status: 503)])
    let link = try NZBLink("nzblnk:?h=fixture&t=Fixture")
    await #expect(throws: (any Error).self) { try await NZBResolver(transport: transport).fileForExport(link) }
}

@Test func rejectsInvalidNZBFromPublicDownload() async throws {
    let transport = ExportTransport([indexResult(), HTTPResult(data: Data("<html>not an NZB</html>".utf8), status: 200)])
    let link = try NZBLink("nzblnk:?h=fixture&t=Fixture")
    await #expect(throws: (any Error).self) { try await NZBResolver(transport: transport).fileForExport(link) }
}

@Test func exportFilenameRemovesDuplicateExtensionAndUnsafeCharacters() {
    #expect(NZBExport.filename(title: "../Release.nzb") == "Release.nzb")
    #expect(NZBExport.filename(title: " / ") == "NZB.nzb")
}

@Test func exportWithoutPasswordPreservesOriginalNZBBytes() throws {
    let original = Data("<nzb><file/></nzb>".utf8)
    let file = try NZBExport.file(data: original, title: "Release", password: nil)
    #expect(file.data == original)
}

@Test func exportRejectsPasswordContainingInvalidXMLControl() throws {
    #expect(throws: (any Error).self) {
        try NZBExport.file(data: Data("<nzb/>".utf8), title: "Release", password: "bad\u{0001}password")
    }
}

@Test func exportValidatesOriginalInputBeforeAddingPassword() {
    #expect(throws: (any Error).self) {
        try NZBExport.file(data: Data("<!DOCTYPE nzb [<!ENTITY x 'bad'>]><nzb/>".utf8), title: "Release", password: "pw")
    }
}

@Test func exportReplacesExistingPasswordMetadata() throws {
    let source = Data("<nzb><head><meta type=\"password\">old</meta></head><file/></nzb>".utf8)
    let file = try NZBExport.file(data: source, title: "Release", password: "exact/new&\"pw")
    #expect(try passwordMetadata(in: file.data) == ["exact/new&\"pw"])
}

@Test func fileForExportUsesExistingNewznabCredentialedFileLoader() async throws {
    let apiKey = "synthetic-export-key"
    let id = "0123456789abcdef0123456789abcdef"
    let rss = """
    <rss xmlns:newznab="http://www.newznab.com/DTD/2010/feeds/attributes/"><channel><item>
      <title>Release.S01E01</title><guid id="\(id)"/>
    </item></channel></rss>
    """
    let transport = ExportTransport([
        HTTPResult(data: Data("invalid JSON".utf8), status: 200),
        HTTPResult(data: Data("<html></html>".utf8), status: 200),
        HTTPResult(data: Data("<html></html>".utf8), status: 200),
        HTTPResult(data: Data(rss.utf8), status: 200),
        HTTPResult(data: Data("<nzb><file/></nzb>".utf8), status: 200)
    ])
    let client = NewznabClient(apiKey: apiKey, service: .newzBay, transport: transport)
    let resolver = NZBResolver(transport: transport, newznabClients: [client])
    let link = try NZBLink("nzblnk:?h=fixture&t=Release.S01E01&p=exact%2Fpassword")
    let file = try await resolver.fileForExport(link)
    #expect(file.title == "Release.S01E01")
    #expect(try passwordMetadata(in: file.data) == ["exact/password"])
    let requests = await transport.captured()
    #expect(requests.count == 5)
    #expect(requests.last?.url?.query?.contains(apiKey) == true)
}

@Test(arguments: [
    "<nzb xmlns=\"urn:sample\"><file/></nzb>",
    "<n:nzb xmlns:n=\"urn:sample\"><n:file/></n:nzb>"
])
func exportAddsPasswordMetadataWithinNamespacedNZB(_ source: String) throws {
    let file = try NZBExport.file(data: Data(source.utf8), title: "Release", password: "exact/password")
    #expect(try passwordMetadata(in: file.data) == ["exact/password"])
}
