// Shape tests for `PlatformName`. It encodes/decodes as a bare JSON string (not an object):
// decoding looks the string up against known platforms (matching by raw value, display name, or
// alias) and normalizes to the canonical known value when found, or keeps the string as a custom
// platform name when not.

import Testing
@testable import DocCSchema

@Suite struct PlatformNameTests {
    @Test func decodesKnownPlatformName() throws {
        let value = try decode(PlatformName.self, "\"macOS\"")
        #expect(value.rawValue == "macOS")
        #expect(value.displayName == "macOS")
        #expect(value.aliases == ["macosx"])

        // Bare top-level scalars aren't valid input to `JSONSerialization.jsonObject`, so the
        // shared `roundTrip` helper can't be used here; encode by hand instead.
        let encoder = RenderJSONEncoder.makeEncoder()
        #expect(String(data: try encoder.encode(value), encoding: .utf8) == "\"macOS\"")
    }

    @Test func decodesKnownAliasNormalizedToCanonicalName() throws {
        // "macosx" is a registered alias of macOS; decoding normalizes it to the canonical name,
        // so re-encoding does not reproduce the original alias string.
        let value = try decode(PlatformName.self, "\"macosx\"")
        #expect(value.rawValue == "macOS")
        #expect(value.displayName == "macOS")
    }

    @Test func decodesUnknownPlatformNameAsCustomValue() throws {
        let value = try decode(PlatformName.self, "\"fooOS\"")
        #expect(value.rawValue == "fooOS")
        #expect(value.displayName == "fooOS")
        #expect(value.aliases.isEmpty)

        let encoder = RenderJSONEncoder.makeEncoder()
        #expect(String(data: try encoder.encode(value), encoding: .utf8) == "\"fooOS\"")
    }

    @Test func roundTripsArrayOfKnownNames() throws {
        let values = try roundTrip([PlatformName].self, "[\"macOS\", \"iOS\", \"linux\"]")
        #expect(values.map(\.rawValue) == ["macOS", "iOS", "linux"])
    }
}
