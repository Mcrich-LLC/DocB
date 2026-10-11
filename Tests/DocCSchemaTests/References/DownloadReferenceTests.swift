// Shape tests for DownloadReference: a reference to a downloadable resource, with an
// optional checksum.

import Testing
@testable import DocCSchema

@Suite struct DownloadReferenceTests {
    @Test func decodesMinimalPayload() throws {
        let reference = try decode(DownloadReference.self, """
        {"type":"download","identifier":"doc://com.example/downloads/sample.zip","url":"https://example.com/sample.zip"}
        """)
        #expect(reference.type == .download)
        #expect(reference.identifier.identifier == "doc://com.example/downloads/sample.zip")
        #expect(reference.url.absoluteString == "https://example.com/sample.zip")
        #expect(reference.checksum == nil)
    }

    @Test func decodesWithChecksum() throws {
        let reference = try decode(DownloadReference.self, """
        {"type":"download","identifier":"doc://com.example/downloads/sample.zip","url":"https://example.com/sample.zip","checksum":"abc123"}
        """)
        #expect(reference.checksum == "abc123")
    }

    @Test func roundTrips() throws {
        try roundTrip(DownloadReference.self, """
        {"type":"download","identifier":"doc://com.example/downloads/sample.zip","url":"https://example.com/sample.zip","checksum":"abc123"}
        """)
    }

    @Test func missingURLThrows() {
        #expect(throws: (any Error).self) {
            try decode(DownloadReference.self, """
            {"type":"download","identifier":"doc://com.example/downloads/sample.zip"}
            """)
        }
    }
}
