// Shape tests for JSONPatchApplier: applying replace/add/remove patch operations directly onto
// encoded JSON data, including its object/array traversal and its error cases.

import Foundation
import Testing
@testable import DocCSchema

@Suite struct JSONPatchApplierTests {
    @Test func replaceUpdatesAnExistingStringValue() throws {
        let original = Data(#"{"title":"Example title","count":1}"#.utf8)
        let patch: JSONPatch = [.replace(pointer: JSONPointer(pathComponents: ["title"]), encodableValue: "Replaced title")]

        let patched = try JSONPatchApplier().apply(patch, to: original)

        let object = try #require(JSONSerialization.jsonObject(with: patched) as? [String: Any])
        #expect(object["title"] as? String == "Replaced title")
        #expect(object["count"] as? Int == 1)
    }

    @Test func addInsertsANewObjectKey() throws {
        let original = Data(#"{"title":"Example title"}"#.utf8)
        let patch: JSONPatch = [.add(pointer: JSONPointer(pathComponents: ["subtitle"]), encodableValue: "Added subtitle")]

        let patched = try JSONPatchApplier().apply(patch, to: original)

        let object = try #require(JSONSerialization.jsonObject(with: patched) as? [String: Any])
        #expect(object["subtitle"] as? String == "Added subtitle")
        #expect(object["title"] as? String == "Example title")
    }

    @Test func removeDeletesAnObjectKey() throws {
        let original = Data(#"{"title":"Example title","count":1}"#.utf8)
        let patch: JSONPatch = [.remove(pointer: JSONPointer(pathComponents: ["count"]))]

        let patched = try JSONPatchApplier().apply(patch, to: original)

        let object = try #require(JSONSerialization.jsonObject(with: patched) as? [String: Any])
        #expect(object["count"] == nil)
        #expect(object["title"] as? String == "Example title")
    }

    @Test func addInsertsAnArrayElementAtIndex() throws {
        let original = Data(#"{"items":["a","b"]}"#.utf8)
        let patch: JSONPatch = [.add(pointer: JSONPointer(pathComponents: ["items", "1"]), encodableValue: "x")]

        let patched = try JSONPatchApplier().apply(patch, to: original)

        let object = try #require(JSONSerialization.jsonObject(with: patched) as? [String: Any])
        let items = try #require(object["items"] as? [String])
        #expect(items == ["a", "x", "b"])
    }

    @Test func throwsWhenReplacingAMissingKey() {
        let original = Data(#"{"title":"Example title"}"#.utf8)
        let patch: JSONPatch = [.replace(pointer: JSONPointer(pathComponents: ["missing"]), encodableValue: "value")]

        #expect(throws: (any Error).self) {
            try JSONPatchApplier().apply(patch, to: original)
        }
    }

    @Test func throwsWhenRemovingTheEntireDocument() {
        let original = Data("{}".utf8)
        let patch: JSONPatch = [.remove(pointer: JSONPointer(pathComponents: []))]

        #expect(throws: (any Error).self) {
            try JSONPatchApplier().apply(patch, to: original)
        }
    }
}
