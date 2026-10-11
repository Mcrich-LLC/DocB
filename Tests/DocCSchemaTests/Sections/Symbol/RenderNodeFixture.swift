// Shared minimal RenderNode JSON wrapper, used by the primary-content-section dispatch
// tests in this folder to exercise CodableContentSection's `kind`-based decoding without
// repeating RenderNode boilerplate in every test file.

/// Wraps `sectionJSON` (a single JSON object literal for a `RenderSection`) as the sole
/// element of a minimal, otherwise-empty `RenderNode`'s `primaryContentSections`.
func renderNodeJSON(primaryContentSection sectionJSON: String) -> String {
    """
    {
      "schemaVersion": {"major": 0, "minor": 3, "patch": 0},
      "identifier": {"url": "doc://com.example/documentation/examplekit/thing", "interfaceLanguage": "swift"},
      "kind": "symbol",
      "sections": [],
      "metadata": {},
      "primaryContentSections": [\(sectionJSON)]
    }
    """
}
