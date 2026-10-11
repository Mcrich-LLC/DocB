// Covers TutorialAssessmentsRenderSection and its nested Assessment/Choice types: the
// multiple-choice "check your understanding" section of a tutorial.
//
// This type (and its nested types) rely on fully-synthesized Codable. Properties with a default
// value are still required keys under synthesis (a missing key throws rather than falling back
// to the default), so minimal payloads below spell out every key, including "kind" and "type".

import Testing
@testable import DocCSchema

@Suite struct TutorialAssessmentsRenderSectionTests {
    @Test func decodesMinimal() throws {
        let json = """
        {
            "kind": "assessments",
            "anchor": "example-assessments",
            "assessments": [
                {
                    "type": "multiple-choice",
                    "title": [{"type": "paragraph", "inlineContent": [{"type": "text", "text": "Example title"}]}],
                    "choices": [
                        {
                            "content": [{"type": "paragraph", "inlineContent": [{"type": "text", "text": "Example title"}]}],
                            "isCorrect": true
                        }
                    ]
                }
            ]
        }
        """
        let value = try decode(TutorialAssessmentsRenderSection.self, json)
        #expect(value.kind == .assessments)
        #expect(value.anchor == "example-assessments")
        #expect(value.assessments.count == 1)
        #expect(value.assessments[0].type == "multiple-choice")
        #expect(value.assessments[0].content == nil)
        #expect(value.assessments[0].choices[0].isCorrect == true)
        #expect(value.assessments[0].choices[0].justification == nil)
        #expect(value.assessments[0].choices[0].reaction == nil)
    }

    @Test func decodesFullPayload() throws {
        let json = """
        {
            "kind": "assessments",
            "anchor": "example-assessments",
            "assessments": [
                {
                    "type": "multiple-choice",
                    "title": [{"type": "paragraph", "inlineContent": [{"type": "text", "text": "Example title"}]}],
                    "content": [{"type": "paragraph", "inlineContent": [{"type": "text", "text": "Example title"}]}],
                    "choices": [
                        {
                            "content": [{"type": "paragraph", "inlineContent": [{"type": "text", "text": "Example title"}]}],
                            "isCorrect": false,
                            "justification": [{"type": "paragraph", "inlineContent": [{"type": "text", "text": "Example title"}]}],
                            "reaction": "Try again"
                        }
                    ]
                }
            ]
        }
        """
        let value = try decode(TutorialAssessmentsRenderSection.self, json)
        #expect(value.assessments[0].content?.count == 1)
        #expect(value.assessments[0].choices[0].reaction == "Try again")
        #expect(value.assessments[0].choices[0].justification?.count == 1)
    }

    @Test func roundTrips() throws {
        let json = """
        {
            "kind": "assessments",
            "anchor": "example-assessments",
            "assessments": [
                {
                    "type": "multiple-choice",
                    "title": [{"type": "paragraph", "inlineContent": [{"type": "text", "text": "Example title"}]}],
                    "choices": [
                        {
                            "content": [{"type": "paragraph", "inlineContent": [{"type": "text", "text": "Example title"}]}],
                            "isCorrect": true,
                            "reaction": "Correct!"
                        }
                    ]
                }
            ]
        }
        """
        try roundTrip(TutorialAssessmentsRenderSection.self, json)
    }

    @Test func decodesInsideRenderNode() throws {
        let sectionJSON = """
        {
            "kind": "assessments",
            "anchor": "example-assessments",
            "assessments": [
                {
                    "type": "multiple-choice",
                    "title": [{"type": "paragraph", "inlineContent": [{"type": "text", "text": "Example title"}]}],
                    "choices": [
                        {
                            "content": [{"type": "paragraph", "inlineContent": [{"type": "text", "text": "Example title"}]}],
                            "isCorrect": true
                        }
                    ]
                }
            ]
        }
        """
        let node = try decode(RenderNode.self, renderNodeJSON(wrapping: sectionJSON))
        let section = try #require(node.sections.first as? TutorialAssessmentsRenderSection)
        #expect(section.anchor == "example-assessments")
    }

    @Test func missingAnchorThrows() {
        let json = """
        {"kind": "assessments", "assessments": []}
        """
        #expect(throws: (any Error).self) {
            try decode(TutorialAssessmentsRenderSection.self, json)
        }
    }
}
