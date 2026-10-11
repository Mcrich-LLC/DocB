// Shape tests for XcodeRequirementReference: the version of Xcode required to follow a
// tutorial, with a download URL.

import Testing
@testable import DocCSchema

@Suite struct XcodeRequirementReferenceTests {
    @Test func decodesPayload() throws {
        let reference = try decode(XcodeRequirementReference.self, """
        {"type":"xcodeRequirement","identifier":"doc://com.example/xcode/16","title":"Xcode 16","url":"https://example.com/xcode16.dmg"}
        """)
        #expect(reference.type == .xcodeRequirement)
        #expect(reference.title == "Xcode 16")
        #expect(reference.url.absoluteString == "https://example.com/xcode16.dmg")
    }

    @Test func roundTrips() throws {
        try roundTrip(XcodeRequirementReference.self, """
        {"type":"xcodeRequirement","identifier":"doc://com.example/xcode/16","title":"Xcode 16","url":"https://example.com/xcode16.dmg"}
        """)
    }

    @Test func missingTitleThrows() {
        #expect(throws: (any Error).self) {
            try decode(XcodeRequirementReference.self, """
            {"type":"xcodeRequirement","identifier":"doc://com.example/xcode/16","url":"https://example.com/xcode16.dmg"}
            """)
        }
    }
}
