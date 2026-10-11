// Shape tests for JSONPatchOperation: coding of the replace/add/remove cases, the "op"/"path"/
// "value" keys, and the computed `pointer`/`operation` accessors.

import Testing
@testable import DocCSchema

@Suite struct JSONPatchOperationTests {
    @Test func decodesReplaceOperation() throws {
        let json = #"{"op":"replace","path":"/metadata/title","value":"Example title"}"#
        let operation = try decode(JSONPatchOperation.self, json)
        #expect(operation.operation == .replace)
        #expect(operation.pointer.pathComponents == ["metadata", "title"])
        guard case .replace = operation else {
            Issue.record("expected .replace case")
            return
        }
    }

    @Test func decodesAddOperation() throws {
        let json = #"{"op":"add","path":"/metadata/subtitle","value":"Example subtitle"}"#
        let operation = try decode(JSONPatchOperation.self, json)
        #expect(operation.operation == .add)
        #expect(operation.pointer.pathComponents == ["metadata", "subtitle"])
    }

    @Test func decodesRemoveOperationWithoutValueKey() throws {
        let json = #"{"op":"remove","path":"/metadata/subtitle"}"#
        let operation = try decode(JSONPatchOperation.self, json)
        #expect(operation.operation == .remove)
        #expect(operation.pointer.pathComponents == ["metadata", "subtitle"])
    }

    @Test func roundTripsReplaceAddAndRemove() throws {
        try roundTrip(JSONPatchOperation.self, #"{"op":"replace","path":"/metadata/title","value":"Example title"}"#)
        try roundTrip(JSONPatchOperation.self, #"{"op":"add","path":"/metadata/title","value":"Example title"}"#)
        try roundTrip(JSONPatchOperation.self, #"{"op":"remove","path":"/metadata/title"}"#)
    }

    @Test func removingPointerFirstPathComponentPreservesOperationAndValue() throws {
        let operation = try decode(JSONPatchOperation.self, #"{"op":"replace","path":"/metadata/title","value":"Example title"}"#)
        let trimmed = operation.removingPointerFirstPathComponent()
        #expect(trimmed.pointer.pathComponents == ["title"])
        #expect(trimmed.operation == .replace)
    }

    @Test func throwsOnUnknownDiscriminator() {
        #expect(throws: (any Error).self) {
            try decode(JSONPatchOperation.self, #"{"op":"bogus","path":"/metadata/title"}"#)
        }
    }
}
