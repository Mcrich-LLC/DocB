import DocCKit

/// App-specific helpers for turning persisted DocC site DTOs into DocCKit framework sections.
extension DocCIndex.InterfaceLanguage {
    /// Converts immediate children into framework sections.
    ///
    /// - Parameter site: Site context used to associate generated sections.
    /// - Returns: Framework sections for child entries that contain valid paths.
    @MainActor
    public func allFrameworkSections(for site: DocCSiteDTO) -> [AppleTechnologies.FrameworkSection] {
        children?.compactMap { frameworkSection(for: $0, site: site) } ?? []
    }
    
    /// Converts an index entry into a framework section for navigation.
    ///
    /// - Parameters:
    ///   - interfaceLanguage: Source index entry.
    ///   - site: Site context to attach to the section.
    /// - Returns: A framework section if the source has a path; otherwise `nil`.
    @MainActor
    public func frameworkSection(for interfaceLanguage: DocCIndex.InterfaceLanguage, site: DocCSiteDTO) -> AppleTechnologies.FrameworkSection? {
        guard let path = interfaceLanguage.path else { return nil }
        
        return AppleTechnologies.FrameworkSection(
            languages: [],
            title: interfaceLanguage.title,
            tags: [],
            destination: .init(type: "", isActive: true, identifier: path),
            legalNotices: nil,
            docCSite: site.docCSource
        )
    }
}

extension DocCSiteDTO {
    /// Returns grouped entries excluding sample code containers and sample code children.
    public var nonSampleCodeGroups: [DocCIndex.InterfaceLanguage] {
        docCSource.nonSampleCodeGroups
    }
}
