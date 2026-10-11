// Covers TutorialSectionsRenderSection and its nested Section type: the ordered list of task
// sections that make up the body of a Tutorial page.

import Testing
@testable import DocCSchema

@Suite struct TutorialSectionsRenderSectionTests {
    @Test func decodesMinimal() throws {
        let json = """
        {
            "kind": "tasks",
            "tasks": [
                {
                    "title": "Example title",
                    "contentSection": [],
                    "stepsSection": [],
                    "anchor": "example-task"
                }
            ]
        }
        """
        let value = try decode(TutorialSectionsRenderSection.self, json)
        #expect(value.kind == .tasks)
        #expect(value.tasks.count == 1)
        #expect(value.tasks[0].title == "Example title")
        #expect(value.tasks[0].anchor == "example-task")
    }

    @Test func decodesFullPayload() throws {
        let json = """
        {
            "kind": "tasks",
            "tasks": [
                {
                    "title": "Example title",
                    "contentSection": [
                        {
                            "kind": "fullWidth",
                            "content": [
                                {"type": "paragraph", "inlineContent": [{"type": "text", "text": "Example title"}]}
                            ]
                        }
                    ],
                    "stepsSection": [
                        {"type": "paragraph", "inlineContent": [{"type": "text", "text": "Example title"}]}
                    ],
                    "anchor": "example-task"
                }
            ]
        }
        """
        let value = try decode(TutorialSectionsRenderSection.self, json)
        #expect(value.tasks[0].contentSection.count == 1)
        #expect(value.tasks[0].stepsSection.count == 1)
    }

    @Test func roundTrips() throws {
        let json = """
        {
            "kind": "tasks",
            "tasks": [
                {
                    "title": "Example title",
                    "contentSection": [],
                    "stepsSection": [],
                    "anchor": "example-task"
                }
            ]
        }
        """
        try roundTrip(TutorialSectionsRenderSection.self, json)
    }

    @Test func decodesInsideRenderNode() throws {
        let sectionJSON = """
        {
            "kind": "tasks",
            "tasks": [
                {
                    "title": "Example title",
                    "contentSection": [],
                    "stepsSection": [],
                    "anchor": "example-task"
                }
            ]
        }
        """
        let node = try decode(RenderNode.self, renderNodeJSON(wrapping: sectionJSON))
        let section = try #require(node.sections.first as? TutorialSectionsRenderSection)
        #expect(section.tasks.count == 1)
    }

    @Test func missingTasksThrows() {
        let json = """
        {"kind": "tasks"}
        """
        #expect(throws: (any Error).self) {
            try decode(TutorialSectionsRenderSection.self, json)
        }
    }
}
