// Shape tests for `SourceLanguage`: {name, id} required, idAliases optional on decode and
// omitted on encode when empty, linkDisambiguationID optional on decode (defaults to id) but
// always emitted on encode.

import Foundation
import Testing
@testable import DocCSchema

@Suite struct SourceLanguageTests {
    @Test func decodesMinimalPayload() throws {
        let value = try roundTrip(SourceLanguage.self, """
        {"name": "Swift", "id": "swift"}
        """)
        #expect(value.name == "Swift")
        #expect(value.id == "swift")
        #expect(value.idAliases.isEmpty)
        #expect(value.linkDisambiguationID == "swift")
    }

    @Test func decodesFullPayload() throws {
        let value = try roundTrip(SourceLanguage.self, """
        {"name": "Custom Lang", "id": "customlang", "idAliases": ["customlang-alt"], "linkDisambiguationID": "cl"}
        """)
        #expect(value.name == "Custom Lang")
        #expect(value.id == "customlang")
        #expect(value.idAliases == ["customlang-alt"])
        #expect(value.linkDisambiguationID == "cl")
    }

    @Test func omitsIdAliasesWhenEmpty() throws {
        let encoder = RenderJSONEncoder.makeEncoder()
        let data = try encoder.encode(SourceLanguage(name: "Swift", id: "swift"))
        let dict = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(dict["idAliases"] == nil)
    }

    @Test func missingRequiredKeyThrows() {
        #expect(throws: (any Error).self) {
            try decode(SourceLanguage.self, """
            {"name": "Swift"}
            """)
        }
    }
}
