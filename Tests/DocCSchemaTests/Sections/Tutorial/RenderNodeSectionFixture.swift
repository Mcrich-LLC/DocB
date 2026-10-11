// Wraps a single tutorial-page section's JSON body inside a minimal RenderNode payload, so tests
// can exercise CodableRenderSection's kind-based dispatch through RenderNode.sections.

/// Builds a minimal RenderNode JSON document containing exactly one section.
///
/// - Parameters:
///   - kind: The RenderNode's own top-level `kind` (unrelated to the section's `kind`).
///   - sectionJSON: The full JSON object literal for the section, e.g. `{"kind": "hero", ...}`.
func renderNodeJSON(kind: String = "project", wrapping sectionJSON: String) -> String {
    """
    {
        "schemaVersion": {"major": 0, "minor": 3, "patch": 0},
        "identifier": {"url": "doc://com.example/tutorials/ExampleKit/Thing", "interfaceLanguage": "swift"},
        "kind": "\(kind)",
        "metadata": {},
        "sections": [\(sectionJSON)]
    }
    """
}
