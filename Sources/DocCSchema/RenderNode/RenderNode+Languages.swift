// The interface languages a render node can be shown in.

extension RenderNode {
    /// The node's own language and every language it has a variant for, by display name.
    public var availableLanguages: [String] {
        var languages = [identifier.sourceLanguage.id]
        for variant in variants ?? [] {
            for trait in variant.traits {
                if case .interfaceLanguage(let language) = trait, !languages.contains(language) { languages.append(language) }
            }
        }
        return languages.sorted { SourceLanguage(id: $0).name < SourceLanguage(id: $1).name }
    }
}
