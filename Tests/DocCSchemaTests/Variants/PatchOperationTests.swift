// Shape tests for PatchOperation: the "op" discriminator's raw string values.

import Testing
@testable import DocCSchema

@Suite struct PatchOperationTests {
    @Test func decodesDocumentedRawValues() throws {
        #expect(try decode(PatchOperation.self, "\"replace\"") == .replace)
        #expect(try decode(PatchOperation.self, "\"add\"") == .add)
        #expect(try decode(PatchOperation.self, "\"remove\"") == .remove)
    }

    @Test func roundTripsToDocumentedRawValues() throws {
        struct Wrapper: Codable { var op: PatchOperation }
        try roundTrip(Wrapper.self, #"{"op":"replace"}"#)
        try roundTrip(Wrapper.self, #"{"op":"add"}"#)
        try roundTrip(Wrapper.self, #"{"op":"remove"}"#)
    }

    @Test func throwsOnUnknownRawValue() {
        #expect(throws: (any Error).self) {
            try decode(PatchOperation.self, "\"bogus\"")
        }
    }
}
