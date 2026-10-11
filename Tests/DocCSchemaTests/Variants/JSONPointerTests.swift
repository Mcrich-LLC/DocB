// Shape tests for JSONPointer: RFC 6901 escaping/unescaping, coding path construction, and coding.

import Testing
@testable import DocCSchema

@Suite struct JSONPointerTests {
    @Test func decodesUnescapedPointer() throws {
        let pointer = try decode(JSONPointer.self, "\"/metadata/title\"")
        #expect(pointer.pathComponents == ["metadata", "title"])
        #expect(pointer.description == "/metadata/title")
    }

    @Test func unescapesTildeAndSlashWhenDecoding() throws {
        let pointer = try decode(JSONPointer.self, "\"/a~0b/c~1d\"")
        #expect(pointer.pathComponents == ["a~b", "c/d"])
    }

    @Test func escapesTildeAndSlashWhenEncoding() {
        let pointer = JSONPointer(pathComponents: ["a~b", "c/d"])
        #expect(pointer.description == "/a~0b/c~1d")
    }

    @Test func initFromCodingPathUsesIntIndicesAsStrings() {
        struct Key: CodingKey {
            var stringValue: String
            var intValue: Int?
            init(_ stringValue: String) {
                self.stringValue = stringValue
                self.intValue = nil
            }
            init(index: Int) {
                self.stringValue = "\(index)"
                self.intValue = index
            }
            init?(stringValue: String) { self.init(stringValue) }
            init?(intValue: Int) { self.init(index: intValue) }
        }

        let pointer = JSONPointer(from: [Key("variants"), Key(index: 2), Key("title")])
        #expect(pointer.pathComponents == ["variants", "2", "title"])
    }

    @Test func removingFirstPathComponentDropsLeadingComponent() {
        let pointer = JSONPointer(pathComponents: ["metadata", "title"])
        #expect(pointer.removingFirstPathComponent().pathComponents == ["title"])
    }

    @Test func roundTripsThroughAContainer() throws {
        struct Wrapper: Codable {
            var pointer: JSONPointer
        }
        let json = """
        { "pointer": "/metadata/title" }
        """
        let wrapper = try roundTrip(Wrapper.self, json)
        #expect(wrapper.pointer.pathComponents == ["metadata", "title"])
    }
}
