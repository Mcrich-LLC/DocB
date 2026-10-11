// Shape tests for `DataTraitCollection`, the {userInterfaceStyle, displayScale} pairing used to
// key `DataAsset` variants. Both fields are optional, so a bare `{}` decodes fine.

import Testing
@testable import DocCSchema

@Suite struct DataTraitCollectionTests {
    @Test func decodesEmptyPayload() throws {
        let value = try roundTrip(DataTraitCollection.self, "{}")
        #expect(value.userInterfaceStyle == nil)
        #expect(value.displayScale == nil)
    }

    @Test func decodesFullPayload() throws {
        let value = try roundTrip(DataTraitCollection.self, """
        {"userInterfaceStyle": "dark", "displayScale": "3x"}
        """)
        #expect(value.userInterfaceStyle == .dark)
        #expect(value.displayScale == .triple)
    }

    @Test func decodesPartialPayload() throws {
        let value = try roundTrip(DataTraitCollection.self, """
        {"displayScale": "2x"}
        """)
        #expect(value.userInterfaceStyle == nil)
        #expect(value.displayScale == .double)
    }
}
