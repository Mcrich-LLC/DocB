// Shape tests for BuildMetadata, the archive-level metadata.json.

import Testing
@testable import DocCSchema

@Suite struct BuildMetadataTests {
    @Test func decodesAndRoundTrips() throws {
        let metadata = try roundTrip(BuildMetadata.self, """
        {"bundleDisplayName": "Example Kit", "bundleIdentifier": "com.example.ExampleKit", "schemaVersion": {"major": 0, "minor": 1, "patch": 0}}
        """)
        #expect(metadata.bundleDisplayName == "Example Kit")
        #expect(metadata.bundleID == "com.example.ExampleKit")
        #expect(metadata.schemaVersion == SemanticVersion(major: 0, minor: 1, patch: 0))
    }

    @Test func missingIdentifierThrows() {
        #expect(throws: (any Error).self) {
            try decode(BuildMetadata.self, #"{"bundleDisplayName": "Example Kit"}"#)
        }
    }
}
