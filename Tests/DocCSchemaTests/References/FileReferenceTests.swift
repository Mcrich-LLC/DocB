// Shape tests for FileReference: the line-by-line contents of a source file, with optional
// line highlights.

import Testing
@testable import DocCSchema

@Suite struct FileReferenceTests {
    @Test func decodesMinimalPayload() throws {
        let reference = try decode(FileReference.self, """
        {
          "type": "file",
          "identifier": "doc://com.example/files/thing.swift",
          "fileName": "thing.swift",
          "fileType": "swift",
          "syntax": "swift",
          "content": ["struct Thing {}"]
        }
        """)
        #expect(reference.type == .file)
        #expect(reference.fileName == "thing.swift")
        #expect(reference.content == ["struct Thing {}"])
        #expect(reference.highlights.isEmpty)
    }

    @Test func decodesWithHighlights() throws {
        let reference = try decode(FileReference.self, """
        {
          "type": "file",
          "identifier": "doc://com.example/files/thing.swift",
          "fileName": "thing.swift",
          "fileType": "swift",
          "syntax": "swift",
          "content": ["struct Thing {}", "// comment"],
          "highlights": [{"line": 1, "start": 0, "length": 6}, {"line": 2}]
        }
        """)
        #expect(reference.highlights.count == 2)
        #expect(reference.highlights[0].line == 1)
        #expect(reference.highlights[0].start == 0)
        #expect(reference.highlights[0].length == 6)
        #expect(reference.highlights[1].start == nil)
    }

    @Test func roundTrips() throws {
        try roundTrip(FileReference.self, """
        {
          "type": "file",
          "identifier": "doc://com.example/files/thing.swift",
          "fileName": "thing.swift",
          "fileType": "swift",
          "syntax": "swift",
          "content": ["struct Thing {}"],
          "highlights": [{"line": 1, "start": 0, "length": 6}]
        }
        """)
    }

    @Test func missingContentThrows() {
        #expect(throws: (any Error).self) {
            try decode(FileReference.self, """
            {
              "type": "file",
              "identifier": "doc://com.example/files/thing.swift",
              "fileName": "thing.swift",
              "fileType": "swift",
              "syntax": "swift"
            }
            """)
        }
    }
}
