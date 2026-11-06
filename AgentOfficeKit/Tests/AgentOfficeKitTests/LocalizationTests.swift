import Foundation
import Testing

/// Checks the string catalogs of the package and both apps, so no screen shows an untranslated line.
struct LocalizationTests {

    private static let repository = URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()

    static let catalogs = [
        "AgentOfficeKit/Sources/AgentOfficeKit/Localizable.xcstrings",
        "AgentOffice/Localizable.xcstrings",
        "AgentOfficeMac/Localizable.xcstrings",
    ]

    private struct Catalog: Decodable {
        struct Entry: Decodable {
            let localizations: [String: Localization]?
        }
        struct Localization: Decodable {
            let stringUnit: StringUnit?
        }
        struct StringUnit: Decodable {
            let state: String
            let value: String
        }
        let sourceLanguage: String
        let strings: [String: Entry]
    }

    /// The placeholders in a line, such as `%@` and `%lld`, in order.
    private static func placeholders(in text: String) -> [String] {
        text.matches(of: /%(?:\d+\$)?(?:lld|@)/).map { String($0.output).replacing(/\d+\$/, with: "") }
    }

    @Test(arguments: catalogs)
    func everyLineHasAKoreanTranslation(path: String) throws {
        let data = try Data(contentsOf: Self.repository.appending(path: path))
        let catalog = try JSONDecoder().decode(Catalog.self, from: data)

        #expect(catalog.sourceLanguage == "en")
        #expect(!catalog.strings.isEmpty)
        for (key, entry) in catalog.strings {
            let korean = try #require(entry.localizations?["ko"]?.stringUnit, "\(key)")
            #expect(korean.state == "translated", "\(key)")
            #expect(!korean.value.isEmpty, "\(key)")
            #expect(Self.placeholders(in: korean.value).sorted() == Self.placeholders(in: key).sorted(), "\(key)")
        }
    }
}
