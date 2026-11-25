import AppKit
import Observation
import RelayCore

@MainActor @Observable
final class DownloadFolderMonitor {
    private(set) var folder: URL?
    @ObservationIgnored var onFiles: (([WatchedNZBFile]) -> Void)?
    @ObservationIgnored var onError: (() -> Void)?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private let defaults: UserDefaults
    private static let preference = "watchedDownloadFolder"
    private static let pendingPathPreference = "pendingWatchedDownloadFolderPath"

    init(defaults: UserDefaults) { self.defaults = defaults }

    var backupPath: String? { folder?.path ?? defaults.string(forKey: Self.pendingPathPreference) }

    func restore() {
        guard let bookmark = defaults.data(forKey: Self.preference) else { return }
        var stale = false
        let scoped = try? URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope, .withoutUI],
                              relativeTo: nil, bookmarkDataIsStale: &stale)
        let url = scoped ?? (try? URL(resolvingBookmarkData: bookmark, options: .withoutUI,
                                      relativeTo: nil, bookmarkDataIsStale: &stale))
        guard let url else { onError?(); return }
        if stale, let bookmark = try? makeBookmark(for: url) { defaults.set(bookmark, forKey: Self.preference) }
        start(url)
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        let suggested = defaults.string(forKey: Self.pendingPathPreference).map { URL(fileURLWithPath: $0, isDirectory: true) }
        panel.directoryURL = folder ?? suggested ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        panel.message = L("Wähle den Ordner, in dem dein Browser fertige NZB-Dateien speichert.")
        panel.begin { [weak self] result in
            guard result == .OK, let self, let url = panel.url else { return }
            do {
                let bookmark = try self.makeBookmark(for: url)
                self.defaults.set(bookmark, forKey: Self.preference)
                self.defaults.removeObject(forKey: Self.pendingPathPreference)
                self.start(url)
            } catch { self.onError?() }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        folder = nil
        defaults.removeObject(forKey: Self.preference)
        defaults.removeObject(forKey: Self.pendingPathPreference)
    }

    /// Keep an existing folder grant. A backup path alone cannot authorize a new folder.
    func restoreBackupPath(_ path: String?) -> Bool {
        if let path, folder?.standardizedFileURL.path == URL(fileURLWithPath: path).standardizedFileURL.path {
            return false
        }
        stop()
        if let path { defaults.set(path, forKey: Self.pendingPathPreference) }
        return path != nil
    }

    private func makeBookmark(for url: URL) throws -> Data {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        return try (try? url.bookmarkData(options: .withSecurityScope))
            ?? url.bookmarkData(options: .minimalBookmark)
    }

    private func start(_ url: URL) {
        task?.cancel()
        folder = url
        task = Task.detached(priority: .utility) { [weak self] in
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                var scanner = try DownloadFolderScanner(folder: url)
                while !Task.isCancelled {
                    try await Task.sleep(for: .seconds(2))
                    let files = try scanner.poll()
                    if !files.isEmpty { await self?.report(files) }
                }
            } catch {
                await self?.reportFailure()
            }
        }
    }

    private func report(_ files: [WatchedNZBFile]) {
        guard !Task.isCancelled else { return }
        onFiles?(files)
    }

    private func reportFailure() {
        guard !Task.isCancelled else { return }
        folder = nil
        task = nil
        onError?()
    }
}

struct WatchedNZBFile: Sendable {
    let file: NZBFile
    let source: WatchedNZBSource
}

struct WatchedNZBSource: Sendable {
    let folder: URL
    let url: URL
    let device: dev_t
    let inode: ino_t

    @discardableResult
    func moveToTrash(ifUnchanged expected: Data) throws -> URL? {
        let scoped = folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
        var info = stat()
        if lstat(url.path, &info) != 0, errno == ENOENT { return nil }
        guard let current = try Self.read(url, size: expected.count),
              current.device == device, current.inode == inode, current.bytes == expected else {
            throw CocoaError(.fileWriteUnknown)
        }
        var trashed: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &trashed)
        return trashed as URL?
    }

    static func read(_ url: URL, size: Int) throws -> (bytes: Data, device: dev_t, inode: ino_t)? {
        let descriptor = open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
        guard descriptor >= 0 else { return nil }
        let file = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? file.close() }
        var info = stat()
        guard fstat(descriptor, &info) == 0, info.st_mode & S_IFMT == S_IFREG,
              info.st_size == size, let bytes = try file.read(upToCount: size + 1),
              bytes.count == size else { return nil }
        return (bytes, info.st_dev, info.st_ino)
    }
}

struct DownloadFolderScanner {
    private struct Stamp: Equatable {
        let size: Int
        let modified: Date?
        let created: Date?
    }

    private static let keys: Set<URLResourceKey> = [
        .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey
    ]

    private let folder: URL
    private var handled: [URL: Stamp]
    private var previous: [URL: Stamp]

    init(folder: URL) throws {
        self.folder = folder
        let existing = try Self.snapshot(folder)
        handled = existing
        previous = existing
    }

    mutating func poll() throws -> [WatchedNZBFile] {
        let current = try Self.snapshot(folder)
        handled = handled.filter { current[$0.key] != nil }
        defer { previous = current }
        var files: [WatchedNZBFile] = []
        var remainingBytes = 64 * 1024 * 1024
        for (url, stamp) in current.sorted(by: { $0.key.lastPathComponent < $1.key.lastPathComponent }) {
            guard previous[url] == stamp, handled[url] != stamp else { continue }
            guard stamp.size <= remainingBytes, files.count < 50 else { break }
            guard let read = try? WatchedNZBSource.read(url, size: stamp.size),
                  Self.stamp(url) == stamp else { continue }
            handled[url] = stamp
            guard let file = try? NZBFile(data: read.bytes, filename: url.lastPathComponent) else { continue }
            remainingBytes -= file.data.count
            files.append(WatchedNZBFile(file: file, source: WatchedNZBSource(
                folder: folder, url: url, device: read.device, inode: read.inode
            )))
        }
        return files
    }

    private static func snapshot(_ folder: URL) throws -> [URL: Stamp] {
        let entries = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil,
                                                                  options: .skipsHiddenFiles)
        var result: [URL: Stamp] = [:]
        for url in entries where url.pathExtension.lowercased() == "nzb" {
            result[url] = stamp(url)
        }
        return result
    }

    private static func stamp(_ url: URL) -> Stamp? {
        var uncachedURL = url
        uncachedURL.removeAllCachedResourceValues()
        guard let values = try? uncachedURL.resourceValues(forKeys: keys),
              values.isRegularFile == true, values.isSymbolicLink != true,
              let size = values.fileSize, (1...16 * 1024 * 1024).contains(size) else { return nil }
        return Stamp(size: size, modified: values.contentModificationDate, created: values.creationDate)
    }
}
