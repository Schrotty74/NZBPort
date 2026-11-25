import Foundation
import Testing
@testable import NZBRelay

@Test func downloadFolderImportsOnlyNewAndCompleteFilesOnce() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: directory) }
    let nzb = Data("<nzb><file/></nzb>".utf8)
    let existing = directory.appendingPathComponent("existing.nzb")
    let unfinished = directory.appendingPathComponent("browser.nzb.download")
    let finished = directory.appendingPathComponent("browser.nzb")
    let invalid = directory.appendingPathComponent("invalid.nzb")
    let symbolicLink = directory.appendingPathComponent("linked.nzb")

    try nzb.write(to: existing)
    var scanner = try DownloadFolderScanner(folder: directory)
    try nzb.write(to: unfinished)
    try Data("<html/>".utf8).write(to: invalid)
    try FileManager.default.createSymbolicLink(at: symbolicLink, withDestinationURL: existing)
    #expect(try scanner.poll().isEmpty)
    #expect(try scanner.poll().isEmpty)

    try FileManager.default.moveItem(at: unfinished, to: finished)
    #expect(try scanner.poll().isEmpty)
    let imported = try scanner.poll()
    #expect(imported.map(\.file.title) == ["browser"])
    #expect(imported.first?.file.data == nzb)
    #expect(try scanner.poll().isEmpty)
}

@Test func downloadFolderWaitsForChangingFilesToSettle() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: directory) }
    var scanner = try DownloadFolderScanner(folder: directory)
    let working = directory.appendingPathComponent("working.nzb")
    try Data("<nzb>".utf8).write(to: working)
    #expect(try scanner.poll().isEmpty)
    try Data("<nzb><file/></nzb>".utf8).write(to: working)
    #expect(try scanner.poll().isEmpty)
    #expect(try scanner.poll().map(\.file.title) == ["working"])
}

@Test func downloadFolderKeepsFileReplacedSinceImport() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: directory) }
    var scanner = try DownloadFolderScanner(folder: directory)
    let url = directory.appendingPathComponent("replaced.nzb")
    let nzb = Data("<nzb><file/></nzb>".utf8)
    try nzb.write(to: url)
    _ = try scanner.poll()
    let imported = try #require(try scanner.poll().first)
    try FileManager.default.moveItem(at: url, to: directory.appendingPathComponent("moved.nzb"))
    try nzb.write(to: url)
    #expect(throws: CocoaError.self) { try imported.source.moveToTrash(ifUnchanged: nzb) }
    #expect(FileManager.default.fileExists(atPath: url.path))
}

@Test func downloadFolderMovesTheOriginalFileToTrash() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: directory) }
    var scanner = try DownloadFolderScanner(folder: directory)
    let url = directory.appendingPathComponent(UUID().uuidString + ".nzb")
    let nzb = Data("<nzb><file/></nzb>".utf8)
    try nzb.write(to: url)
    _ = try scanner.poll()
    let imported = try #require(try scanner.poll().first)
    let trashed = try #require(try imported.source.moveToTrash(ifUnchanged: nzb))
    defer { try? FileManager.default.removeItem(at: trashed) }
    #expect(!FileManager.default.fileExists(atPath: url.path))
}
