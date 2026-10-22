import Foundation

public struct NZBFile: Sendable, Identifiable {
    public let id: UUID
    public let title: String
    public let data: Data

    public init(url: URL) throws {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true, let size = values.fileSize, size <= 16 * 1024 * 1024 else {
            throw RelayError.message("Choose an NZB file smaller than 16 MiB.")
        }
        let bytes = try Data(contentsOf: url, options: .mappedIfSafe)
        try self.init(validating: bytes, filename: url.lastPathComponent)
    }

    public init(data: Data, filename: String) throws {
        try self.init(validating: data, filename: filename)
    }

    private init(validating data: Data, filename: String) throws {
        guard data.count <= 16 * 1024 * 1024 else { throw RelayError.message("Choose an NZB file smaller than 16 MiB.") }
        let safeName = URL(fileURLWithPath: filename).lastPathComponent
        guard !safeName.isEmpty, !safeName.contains("\r"), !safeName.contains("\n"), !safeName.contains("\""), !safeName.contains("\\"), safeName.lowercased().hasSuffix(".nzb") else {
            throw RelayError.message("Choose a valid .nzb file.")
        }
        guard !Self.containsEntityDeclaration(data) else { throw RelayError.message("The NZB file is invalid.") }
        let parser = XMLParser(data: data)
        let validator = NZBXMLValidator()
        parser.delegate = validator
        parser.shouldResolveExternalEntities = false
        guard parser.parse(), validator.rootIsNZB else { throw RelayError.message("The NZB file is invalid.") }
        self.id = UUID(); self.title = String(safeName.dropLast(4)); self.data = data
    }

    private static func containsEntityDeclaration(_ data: Data) -> Bool {
        let bytes = [UInt8](data)
        let text: String
        if bytes.starts(with: [0xFF, 0xFE]) || bytes.starts(with: [0xFE, 0xFF]) {
            text = String(data: data, encoding: .utf16) ?? ""
        } else if bytes.starts(with: [0x00, 0x3C, 0x00]) {
            text = String(decoding: stride(from: 0, to: bytes.count - bytes.count % 2, by: 2).map { UInt16(bytes[$0]) << 8 | UInt16(bytes[$0 + 1]) }, as: UTF16.self)
        } else if bytes.starts(with: [0x3C, 0x00]) {
            text = String(decoding: stride(from: 0, to: bytes.count - bytes.count % 2, by: 2).map { UInt16(bytes[$0]) | UInt16(bytes[$0 + 1]) << 8 }, as: UTF16.self)
        } else {
            text = String(decoding: data, as: UTF8.self)
        }
        let withoutComments = text.replacingOccurrences(of: #"(?s)<!--.*?-->"#, with: "", options: .regularExpression)
        let withoutCDATA = withoutComments.replacingOccurrences(of: #"(?s)<!\[CDATA\[.*?\]\]>"#, with: "", options: .regularExpression)
        return withoutCDATA.contains("<!ENTITY")
    }
}

private final class NZBXMLValidator: NSObject, XMLParserDelegate {
    private(set) var rootIsNZB = false
    private var sawRootElement = false

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        guard !sawRootElement else { return }
        sawRootElement = true
        rootIsNZB = elementName == "nzb" || elementName.hasSuffix(":nzb")
        if !rootIsNZB { parser.abortParsing() }
    }

    func parser(_ parser: XMLParser, foundInternalEntityDeclarationWithName name: String, value: String?) {
        parser.abortParsing()
    }

    func parser(_ parser: XMLParser, foundExternalEntityDeclarationWithName name: String, publicID: String?, systemID: String?) {
        parser.abortParsing()
    }
}
