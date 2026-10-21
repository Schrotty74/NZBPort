import Foundation
import Testing
@testable import RelayCore

@Test(arguments: [
    ("de-DE", "en-US", AppLanguage.german),
    ("fr-FR", "de-AT", AppLanguage.german),
    ("fr-FR", "en-US", AppLanguage.english),
    ("fr-FR", "ja-JP", AppLanguage.english)
])
func systemLanguageUsesFirstSupportedPreference(
    _ first: String,
    _ second: String,
    _ expected: AppLanguage
) {
    #expect(AppLanguage.resolved(.system, preferredLanguages: [first, second]) == expected)
}

@Test func explicitLanguageOverridesSystemAndSystemFallsBackToEnglish() {
    #expect(AppLanguage.resolved(.german, preferredLanguages: ["en-US"]) == .german)
    #expect(AppLanguage.resolved(.english, preferredLanguages: ["de-DE"]) == .english)
    #expect(AppLanguage.resolved(.system, preferredLanguages: ["fr-FR"]) == .english)
}

@Test func relayErrorsTranslateAndKeepInterpolatedArguments() {
    let german = Localization.string(
        "The search service returned HTTP \(503).",
        table: "Errors",
        language: .german
    )
    let english = Localization.string(
        "The search service returned HTTP \(503).",
        table: "Errors",
        language: .english
    )

    #expect(german == "Suchdienst antwortet mit HTTP 503.")
    #expect(english == "The search service returned HTTP 503.")
}

@Test func interfaceTranslationsPreserveCategoryNamesAndCounts() {
    let category = "Movies & TV"
    let count = 3
    #expect(Localization.string("An SABnzbd senden: \(category)", language: .english) == "Send to SABnzbd: Movies & TV")
    #expect(Localization.string("An SABnzbd senden: \(category)", language: .german) == "An SABnzbd senden: Movies & TV")
    #expect(Localization.string("\(count) Kategorien von SABnzbd geladen", language: .english) == "Categories loaded from SABnzbd: 3")
    #expect(Localization.string("\(count) weitere Links", language: .german) == "3 weitere Links")
}

@Test func languageTablesHaveCompleteMatchingKeysAndFormats() throws {
    for table in ["Interface", "Errors"] {
        let englishURL = try #require(Localization.resourceBundle(for: .english).url(forResource: table, withExtension: "strings"))
        let germanURL = try #require(Localization.resourceBundle(for: .german).url(forResource: table, withExtension: "strings"))
        let english = try #require(PropertyListSerialization.propertyList(from: Data(contentsOf: englishURL), format: nil) as? [String: String])
        let german = try #require(PropertyListSerialization.propertyList(from: Data(contentsOf: germanURL), format: nil) as? [String: String])
        #expect(Set(english.keys) == Set(german.keys))
        let format = try NSRegularExpression(pattern: "%(@|lld)")
        func placeholders(_ value: String) -> [String] {
            format.matches(in: value, range: NSRange(value.startIndex..., in: value)).map {
                String(value[Range($0.range, in: value)!])
            }.sorted()
        }
        for (key, value) in english {
            #expect(!value.isEmpty)
            #expect(placeholders(key) == placeholders(value))
            #expect(placeholders(key) == placeholders(german[key] ?? ""))
        }
    }
}
