// Covers RenderNode.Tag's shape and its pre-defined `.spi` tag.

import Testing
@testable import DocCSchema

@Suite struct RenderNodeTagTests {
    @Test func decodesTag() throws {
        let tag = try decode(RenderNode.Tag.self, """
        { "type": "spi", "text": "SPI" }
        """)
        #expect(tag.type == "spi")
        #expect(tag.text == "SPI")
    }

    @Test func roundTrips() throws {
        try roundTrip(RenderNode.Tag.self, """
        { "type": "beta", "text": "Beta" }
        """)
    }

    @Test func decodedSPITagMatchesStaticConstant() throws {
        let tag = try decode(RenderNode.Tag.self, """
        { "type": "spi", "text": "SPI" }
        """)
        #expect(tag == RenderNode.Tag.spi)
    }
}
