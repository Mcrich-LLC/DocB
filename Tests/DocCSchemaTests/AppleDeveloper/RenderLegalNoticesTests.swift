// Shape tests for RenderLegalNotices: the copyright and policy links attached to a
// developer.apple.com render node.

import Testing
@testable import DocCSchema

@Suite struct RenderLegalNoticesTests {
    @Test func decodesPayload() throws {
        let json = """
        {
            "copyright": "Copyright &copy; 2026 Example Inc. All rights reserved.",
            "privacyPolicy": "https://example.com/privacy",
            "termsOfUse": "https://example.com/terms"
        }
        """
        let notices = try decode(RenderLegalNotices.self, json)
        #expect(notices.copyright == "Copyright &copy; 2026 Example Inc. All rights reserved.")
        #expect(notices.privacyPolicy == "https://example.com/privacy")
        #expect(notices.termsOfUse == "https://example.com/terms")
    }

    @Test func roundTrips() throws {
        let json = """
        {
            "copyright": "Copyright &copy; 2026 Example Inc. All rights reserved.",
            "privacyPolicy": "https://example.com/privacy",
            "termsOfUse": "https://example.com/terms"
        }
        """
        try roundTrip(RenderLegalNotices.self, json)
    }

    @Test func missingRequiredKeyThrows() throws {
        let json = """
        { "copyright": "Copyright &copy; 2026 Example Inc.", "privacyPolicy": "https://example.com/privacy" }
        """
        #expect(throws: (any Error).self) {
            try decode(RenderLegalNotices.self, json)
        }
    }
}
