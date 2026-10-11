# AppleDeveloper

Types for the parts of developer.apple.com's render JSON that are not part of upstream
swift-docc: the documentation homepage (`documentation.json`, kind `root`), the technologies
catalog (`documentation/technologies.json`, kind `technologies`), and the `legalNotices`
object attached to those pages. Ordinary symbol pages also reference the catalog, so the
`RenderNode.Kind.technologies` case is needed to decode them.

Hooks into upstream enums live in the copied files and are marked `// AppleDeveloper:`
inline, with an `// Extended:` line in the file header:

- `RenderNode.Kind` gains `root` and `technologies`.
- `RenderSectionKind` gains `section`, `homepageResources`, and `technologies`.
- `CodableRenderSection` decodes those three kinds.
- `RenderHierarchy` gains `homepage(RenderHomepageHierarchy)`.
- `RenderNode` gains `legalNotices`.

Everything in this folder follows upstream naming: `<Thing>RenderSection` for sections,
`Render<Thing>` for node-level values, nested `Kind` enums for discriminators. Shapes were
derived from live payloads; the JSON keys are the source of truth for property names.
