// Shape tests for `SemanticVersion`: only `major` is required on decode, `minor`/`patch`
// default to 0, and `prerelease`/`buildMetadata` are omitted on encode when nil.

import Testing
@testable import DocCSchema

@Suite struct SemanticVersionTests {
    @Test func decodesMinimalPayload() throws {
        let value = try roundTrip(SemanticVersion.self, """
        {"major": 1}
        """)
        #expect(value.major == 1)
        #expect(value.minor == 0)
        #expect(value.patch == 0)
        #expect(value.prerelease == nil)
        #expect(value.buildMetadata == nil)
    }

    @Test func decodesFullPayload() throws {
        let value = try roundTrip(SemanticVersion.self, """
        {"major": 2, "minor": 5, "patch": 9, "prerelease": "beta.1", "buildMetadata": "build.42"}
        """)
        #expect(value.major == 2)
        #expect(value.minor == 5)
        #expect(value.patch == 9)
        #expect(value.prerelease == "beta.1")
        #expect(value.buildMetadata == "build.42")
        #expect(value.description == "2.5.9-beta.1+build.42")
    }

    @Test func missingRequiredKeyThrows() {
        #expect(throws: (any Error).self) {
            try decode(SemanticVersion.self, "{}")
        }
    }
}
