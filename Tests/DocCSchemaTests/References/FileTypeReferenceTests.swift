// Shape tests for FileTypeReference: a display name and Base64-encoded icon for a kind of
// file, not a specific file.

import Testing
import Foundation
@testable import DocCSchema

@Suite struct FileTypeReferenceTests {
    @Test func decodesPayload() throws {
        let reference = try decode(FileTypeReference.self, """
        {
          "type": "fileType",
          "identifier": "doc://com.example/fileTypes/swift",
          "displayName": "Swift File",
          "iconBase64": "aGVsbG8="
        }
        """)
        #expect(reference.type == .fileType)
        #expect(reference.displayName == "Swift File")
        #expect(reference.iconBase64 == Data("hello".utf8))
    }

    @Test func roundTrips() throws {
        try roundTrip(FileTypeReference.self, """
        {
          "type": "fileType",
          "identifier": "doc://com.example/fileTypes/swift",
          "displayName": "Swift File",
          "iconBase64": "aGVsbG8="
        }
        """)
    }

    @Test func missingDisplayNameThrows() {
        #expect(throws: (any Error).self) {
            try decode(FileTypeReference.self, """
            {
              "type": "fileType",
              "identifier": "doc://com.example/fileTypes/swift",
              "iconBase64": "aGVsbG8="
            }
            """)
        }
    }
}
