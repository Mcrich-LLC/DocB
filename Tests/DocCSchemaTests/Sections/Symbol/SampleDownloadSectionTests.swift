// Shape tests for SampleDownloadSection: a sample project's download call-to-action.
// Not dispatched via RenderNode.primaryContentSections/CodableContentSection (its
// "sampleDownload" kind has no case in that switch); it's decoded directly from
// RenderNode's own `sampleCodeDownload` key instead, so no RenderNode dispatch test applies.

import Testing
@testable import DocCSchema

@Suite struct SampleDownloadSectionTests {
    static let minimalJSON = """
    {
      "kind": "sampleDownload",
      "action": { "type": "text", "text": "Download" }
    }
    """

    @Test func decodesPayload() throws {
        let section = try decode(SampleDownloadSection.self, Self.minimalJSON)
        #expect(section.kind == .sampleDownload)
        #expect(section.action == .text("Download"))
    }

    @Test func roundTrips() throws {
        try roundTrip(SampleDownloadSection.self, Self.minimalJSON)
    }

    @Test func missingActionThrows() throws {
        #expect(throws: (any Error).self) {
            try decode(SampleDownloadSection.self, "{ \"kind\": \"sampleDownload\" }")
        }
    }
}
