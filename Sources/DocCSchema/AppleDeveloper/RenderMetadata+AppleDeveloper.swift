// Typed accessors for metadata keys only developer.apple.com emits. Upstream already keeps
// unknown metadata keys in `RenderMetadata.extraMetadata`, so no coding changes are needed.

extension RenderMetadata {
    /// The tags the technologies catalog suggests as default filters.
    public var defaultSuggestedTags: [String]? {
        extraMetadata[CodingKeys(stringValue: "defaultSuggestedTags")] as? [String]
    }
}
