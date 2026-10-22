import Foundation
import Testing
@testable import RelayCore

private actor ExpansionTransport: HTTPTransport {
    var result: HTTPResult
    var lastRequest: URLRequest?
    init(_ result: HTTPResult) { self.result = result }
    func perform(_ request: URLRequest) async throws -> HTTPResult { lastRequest = request; return result }
    func captured() -> URLRequest? { lastRequest }
    func setResult(_ result: HTTPResult) { self.result = result }
}

private func expansionConnection() throws -> ServerConnection { try ServerConnection(address: "https://sab.example/api", apiKey: "secret") }
private func response(_ text: String, status: Int = 200) -> HTTPResult { HTTPResult(data: Data(text.utf8), status: status) }

@Test func localFileUploadSendsMultipartAndPausedPriority() async throws {
    let file = try NZBFile(data: Data("<nzb xmlns=\"urn:test\"><file/></nzb>".utf8), filename: "episode.nzb")
    let transport = ExpansionTransport(response(#"{"status":true,"nzo_ids":["job-1"]}"#))
    let ids = try await SABClient(transport: transport).send(file, category: "Series", connection: expansionConnection(), options: SendOptions(priority: .high, addPaused: true))
    #expect(ids == ["job-1"])
    let req = try #require(await transport.captured())
    #expect(req.httpMethod == "POST")
    #expect(req.url?.query == nil)
    #expect(req.value(forHTTPHeaderField: "Content-Type")?.contains("multipart/form-data") == true)
    let body = String(decoding: try #require(req.httpBody), as: UTF8.self)
    #expect(body.contains("name=\"mode\"\r\n\r\naddfile"))
    #expect(body.contains("name=\"priority\"\r\n\r\n-2"))
    #expect(body.contains("name=\"cat\"\r\n\r\nSeries"))
    #expect(body.contains("<nzb xmlns=\"urn:test\"><file/></nzb>"))
    #expect(body.contains("filename=\"episode.nzb\""))
    #expect(!body.contains("/Users/"))
}

@Test func queueAndHistoryDecodeDocumentedFieldsAndActionsPostCredentials() async throws {
    let t = ExpansionTransport(response(#"{"queue":{"speed":"2 M","timeleft":"0:01:00","paused":true,"slots":[{"nzo_id":"nzo-1","filename":"Episode","status":"Downloading","percentage":"37.5","cat":"TV"}]}}"#))
    let client = SABClient(transport: t)
    let q = try await client.queue(expansionConnection())
    #expect(q.paused && q.speed == "2 M" && q.timeLeft == "0:01:00")
    #expect(q.jobs.first?.progress == 0.375 && q.jobs.first?.category == "TV")
    await t.setResult(response(#"{"history":{"slots":[{"nzo_id":"old","name":"Broken","status":"Failed"},{"nzo_id":"ok","name":"Done","status":"Completed"}]}}"#))
    let h = try await client.history(expansionConnection(), limit: 2)
    #expect(h.map(\.failed) == [true, false])
    await t.setResult(response(#"{"status":true}"#))
    try await client.setJob(.pause, id: "nzo-1", connection: expansionConnection())
    let req = try #require(await t.captured())
    #expect(req.url?.query == nil)
    let body = String(decoding: try #require(req.httpBody), as: UTF8.self)
    #expect(body.contains("name=pause"))
    #expect(body.contains("value=nzo-1"))
    #expect(body.contains("apikey=secret"))
}

@Test(arguments: [
    "<nzb><file>",
    "<!DOCTYPE nzb [<!ENTITY x SYSTEM 'file:///etc/passwd'>]><nzb>&x;</nzb>",
    "<root><nzb/></root>"
])
func nzbFileRejectsInvalidOrUnsafeXML(_ xml: String) {
    #expect(throws: (any Error).self) { try NZBFile(data: Data(xml.utf8), filename: "bad.nzb") }
}

@Test func nzbFileAcceptsStandardExternalDoctypeWithoutFetchingIt() throws {
    let xml = #"<?xml version="1.0"?><!DOCTYPE nzb PUBLIC "-//newzBin//DTD NZB 1.1//EN" "http://www.newznab.com/DTD/nzb/nzb-1.1.dtd"><nzb xmlns="http://www.newznab.com/DTD/2003/nzb"><file/></nzb>"#
    let file = try NZBFile(data: Data(xml.utf8), filename: "valid.nzb")
    #expect(file.title == "valid")
}

@Test func nzbFileRejectsInternalEntityDeclarations() {
    let xml = "<!DOCTYPE nzb [<!ENTITY expansion 'value'>]><nzb>&expansion;</nzb>"
    #expect(throws: (any Error).self) { try NZBFile(data: Data(xml.utf8), filename: "entity.nzb") }

    var utf16 = Data([0xFF, 0xFE])
    for codeUnit in xml.utf16 {
        utf16.append(UInt8(codeUnit & 0xFF))
        utf16.append(UInt8(codeUnit >> 8))
    }
    #expect(throws: (any Error).self) { try NZBFile(data: utf16, filename: "entity.nzb") }
}

@Test func nzbFileRejectsMultipartHeaderInjectionAndWrongExtension() {
    #expect(throws: (any Error).self) { try NZBFile(data: Data("<nzb/>".utf8), filename: "x\"\r\nInjected.nzb") }
    #expect(throws: (any Error).self) { try NZBFile(data: Data("<nzb/>".utf8), filename: "file.txt") }
}
