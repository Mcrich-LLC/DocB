// Shape tests for the `RenderMetadata.defaultSuggestedTags` accessor: the technologies catalog's
// default filter tags, stored in upstream's untyped `extraMetadata` bag. No coding changes are
// involved (see RenderMetadata+AppleDeveloper.swift), so these tests exercise the accessor
// through plain RenderMetadata decode/encode.

import Testing
@testable import DocCSchema

@Suite struct RenderMetadataAppleDeveloperTests {
    @Test func decodesDefaultSuggestedTags() throws {
        let json = """
        { "defaultSuggestedTags": ["Featured", "New"] }
        """
        let metadata = try decode(RenderMetadata.self, json)
        #expect(metadata.defaultSuggestedTags == ["Featured", "New"])
    }

    @Test func missingDefaultSuggestedTagsIsNil() throws {
        let metadata = try decode(RenderMetadata.self, "{}")
        #expect(metadata.defaultSuggestedTags == nil)
    }

    @Test func roundTrips() throws {
        let json = """
        { "defaultSuggestedTags": ["Featured", "New"] }
        """
        let metadata = try roundTrip(RenderMetadata.self, json)
        #expect(metadata.defaultSuggestedTags == ["Featured", "New"])
    }
}
