import Foundation

/// A decoded article and the context needed to render it.
public struct DocCArticlePage: Sendable {
    /// Article payload to render.
    public let article: Article
    /// Reference represented by the article.
    public let reference: Reference
    /// Source context used to resolve relative links and assets.
    public let source: DocCSource
    
    /// Creates a render-ready article page.
    ///
    /// - Parameters:
    ///   - article: Article payload to render.
    ///   - reference: Reference represented by the article.
    ///   - source: Source context used to resolve relative links and assets.
    public init(article: Article, reference: Reference, source: DocCSource) {
        self.article = article
        self.reference = reference
        self.source = source
    }
}

/// A decoded framework and the context needed to render it.
public struct DocCFrameworkPage: Sendable {
    /// Framework payload to render.
    public let framework: Framework
    /// Framework section represented by the framework payload.
    public let frameworkSection: AppleTechnologies.FrameworkSection
    /// Source context used to resolve relative links and assets.
    public let source: DocCSource
    
    /// Creates a render-ready framework page.
    ///
    /// - Parameters:
    ///   - framework: Framework payload to render.
    ///   - frameworkSection: Framework section represented by the framework payload.
    ///   - source: Source context used to resolve relative links and assets.
    public init(framework: Framework, frameworkSection: AppleTechnologies.FrameworkSection, source: DocCSource) {
        self.framework = framework
        self.frameworkSection = frameworkSection
        self.source = source
    }
}
