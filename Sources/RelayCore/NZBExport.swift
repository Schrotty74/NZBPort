import Foundation

/// Builds a safe filename and carries an archive password as NZB metadata.
public enum NZBExport {
    public static func filename(title: String) -> String {
        let forbidden = CharacterSet.controlCharacters.union(CharacterSet(charactersIn: "/\\:*?\"<>|"))
        let replaced = String(title.unicodeScalars.map { forbidden.contains($0) ? "_" : String($0) }.joined())
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "._")))
        var name = replaced.isEmpty ? "NZB" : replaced
        if name.lowercased().hasSuffix(".nzb") { name.removeLast(4) }
        return name + ".nzb"
    }

    /// Adds the exact archive password as NZB metadata while retaining the title as its filename.
    public static func file(data: Data, title: String, password: String? = nil) throws -> NZBFile {
        let filename = filename(title: title)
        let validated = try NZBFile(data: data, filename: filename)
        guard let password, !password.isEmpty else { return validated }
        guard password.unicodeScalars.allSatisfy(isXMLCharacter) else {
            throw RelayError.message("The NZB password contains characters that XML cannot represent.")
        }
        let document: XMLDocument
        do {
            document = try XMLDocument(data: data, options: [.nodeLoadExternalEntitiesNever])
        } catch {
            throw RelayError.message("The NZB file is invalid.")
        }
        guard let root = document.rootElement(), root.localName == "nzb" else {
            throw RelayError.message("The NZB file is invalid.")
        }
        let head: XMLElement
        if let existing = root.children?.compactMap({ $0 as? XMLElement }).first(where: { $0.localName == "head" }) {
            head = existing
        } else {
            let prefix = namespacePrefix(root.name)
            head = XMLElement(name: prefix.map { "\($0):head" } ?? "head")
            root.insertChild(head, at: 0)
        }
        for index in (head.children?.indices ?? 0..<0).reversed() {
            guard let element = head.children?[index] as? XMLElement,
                  element.localName == "meta",
                  element.attribute(forName: "type")?.stringValue == "password" else { continue }
            head.removeChild(at: index)
        }
        let prefix = namespacePrefix(head.name)
        let meta = XMLElement(name: prefix.map { "\($0):meta" } ?? "meta")
        meta.addAttribute(XMLNode.attribute(withName: "type", stringValue: "password") as! XMLNode)
        meta.addChild(XMLNode.text(withStringValue: password) as! XMLNode)
        head.addChild(meta)
        let updated = document.xmlData(options: [])
        return try NZBFile(data: updated, filename: filename)
    }

    private static func isXMLCharacter(_ scalar: Unicode.Scalar) -> Bool {
        let value = scalar.value
        return value == 0x9 || value == 0xA || value == 0xD
            || (0x20...0xD7FF).contains(value)
            || (0xE000...0xFFFD).contains(value)
            || (0x10000...0x10FFFF).contains(value)
    }

    private static func namespacePrefix(_ name: String?) -> String? {
        guard let name, let separator = name.firstIndex(of: ":") else { return nil }
        return String(name[..<separator])
    }
}
