import Foundation

enum SearchHTML {
    struct Tag {
        let name: String
        let attributes: [String: String]
        let isClosing: Bool
    }

    static func tags(in html: String) -> [Tag] {
        let characters = Array(html)
        var result: [Tag] = []
        var index = 0

        while index < characters.count {
            guard characters[index] == "<" else {
                index += 1
                continue
            }

            if matches(characters, at: index, "<!--") {
                index = afterComment(in: characters, from: index + 4)
                continue
            }

            guard let parsed = parseTag(in: characters, at: index) else {
                index += 1
                continue
            }
            result.append(parsed.tag)
            index = parsed.nextIndex

            if !parsed.tag.isClosing, (parsed.tag.name == "script" || parsed.tag.name == "style") {
                index = afterRawTextElement(parsed.tag.name, in: characters, from: index)
            }
        }

        return result
    }

    private static func afterComment(in characters: [Character], from start: Int) -> Int {
        var index = start
        while index + 2 < characters.count {
            if characters[index] == "-", characters[index + 1] == "-", characters[index + 2] == ">" {
                return index + 3
            }
            index += 1
        }
        return characters.count
    }

    private static func afterRawTextElement(_ name: String, in characters: [Character], from start: Int) -> Int {
        var index = start
        while index < characters.count {
            if characters[index] == "<", let parsed = parseTag(in: characters, at: index),
               parsed.tag.isClosing, parsed.tag.name == name {
                return parsed.nextIndex
            }
            index += 1
        }
        return characters.count
    }

    private static func parseTag(in characters: [Character], at start: Int) -> (tag: Tag, nextIndex: Int)? {
        var index = start + 1
        guard index < characters.count else { return nil }

        let isClosing = characters[index] == "/"
        if isClosing { index += 1 }
        guard index < characters.count, !isWhitespace(characters[index]) else { return nil }

        let nameStart = index
        while index < characters.count, isNameCharacter(characters[index]) { index += 1 }
        guard index > nameStart else { return nil }
        let name = String(characters[nameStart..<index]).lowercased()
        var attributes: [String: String] = [:]

        if isClosing {
            while index < characters.count, characters[index] != ">" { index += 1 }
            guard index < characters.count else { return nil }
            return (Tag(name: name, attributes: attributes, isClosing: true), index + 1)
        }

        while index < characters.count {
            while index < characters.count,
                  isWhitespace(characters[index]) || characters[index] == "/" { index += 1 }
            guard index < characters.count else { return nil }
            if characters[index] == ">" {
                return (Tag(name: name, attributes: attributes, isClosing: false), index + 1)
            }

            let attributeStart = index
            while index < characters.count,
                  !isWhitespace(characters[index]), characters[index] != "=",
                  characters[index] != ">", characters[index] != "/" { index += 1 }
            guard index > attributeStart else {
                index += 1
                continue
            }
            let attributeName = String(characters[attributeStart..<index]).lowercased()
            while index < characters.count, isWhitespace(characters[index]) { index += 1 }

            var value = ""
            if index < characters.count, characters[index] == "=" {
                index += 1
                while index < characters.count, isWhitespace(characters[index]) { index += 1 }
                if index < characters.count, characters[index] == "\"" || characters[index] == "'" {
                    let quote = characters[index]
                    index += 1
                    let valueStart = index
                    while index < characters.count, characters[index] != quote { index += 1 }
                    guard index < characters.count else { return nil }
                    value = decodeEntities(String(characters[valueStart..<index]))
                    index += 1
                } else {
                    let valueStart = index
                    while index < characters.count,
                          !isWhitespace(characters[index]), characters[index] != ">" { index += 1 }
                    value = decodeEntities(String(characters[valueStart..<index]))
                }
            }
            if attributes[attributeName] == nil { attributes[attributeName] = value }
        }
        return nil
    }

    private static func decodeEntities(_ value: String) -> String {
        let characters = Array(value)
        var output = ""
        var index = 0
        while index < characters.count {
            guard characters[index] == "&" else {
                output.append(characters[index])
                index += 1
                continue
            }
            var end = index + 1
            while end < characters.count, end - index <= 12,
                  characters[end] != ";", !isWhitespace(characters[end]), characters[end] != "&" { end += 1 }
            guard end < characters.count, characters[end] == ";" else {
                output.append(characters[index])
                index += 1
                continue
            }
            let entity = String(characters[(index + 1)..<end])
            if let decoded = decodeEntity(entity) {
                output.append(decoded)
                index = end + 1
            } else {
                output.append(contentsOf: characters[index...end])
                index = end + 1
            }
        }
        return output
    }

    private static func decodeEntity(_ entity: String) -> String? {
        switch entity.lowercased() {
        case "amp": return "&"
        case "quot": return "\""
        case "apos": return "'"
        case "lt": return "<"
        case "gt": return ">"
        default: break
        }

        guard entity.first == "#" else { return nil }
        let digits = entity.dropFirst()
        let radix: Int
        let number: Substring
        if digits.first == "x" || digits.first == "X" {
            radix = 16
            number = digits.dropFirst()
        } else {
            radix = 10
            number = digits
        }
        guard !number.isEmpty, let scalarValue = UInt32(number, radix: radix),
              let scalar = UnicodeScalar(scalarValue) else { return nil }
        return String(scalar)
    }

    private static func matches(_ characters: [Character], at index: Int, _ string: String) -> Bool {
        let target = Array(string)
        guard index >= 0, index + target.count <= characters.count else { return false }
        for offset in target.indices where characters[index + offset] != target[offset] { return false }
        return true
    }

    private static func isWhitespace(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { CharacterSet.whitespacesAndNewlines.contains($0) }
    }

    private static func isNameCharacter(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy {
            CharacterSet.letters.contains($0) || CharacterSet.decimalDigits.contains($0)
                || $0 == "-" || $0 == ":" || $0 == "_"
        }
    }
}
