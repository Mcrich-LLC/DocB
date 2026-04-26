import SwiftUI
import Testing
@testable import DocCKit

@MainActor
@Observable
private final class TestNavigator: DocCNavigator {
    var reference: Reference?
    var technology: AppleTechnologies.FrameworkSection?
    var isUsingSplitView = false
    var deepLinkScheme = DocCDeepLinkScheme("test-docs")
    
    func setReference(_ reference: Reference?, forceHistory: Bool) {
        self.reference = reference
    }
    
    func setTechnology(_ technology: AppleTechnologies.FrameworkSection?, noHistory: Bool) {
        self.technology = technology
    }
    
    func showHomepage() {
        reference = nil
        technology = nil
    }
}

@MainActor
@Test func articleRendererBuildsWithMinimalNavigator() {
    let navigator = TestNavigator()
    let article = SelfFixtures.article
    
    let view = DocCArticleView(article: article, navigator: navigator)
    
    #expect(view.article.metadata.title == "Example Article")
    #expect(view.reference.identifier == "doc://article/example-article")
    #expect(view.navigator.deepLinkScheme.urlPrefix == "test-docs://")
    _ = view.body
}

@MainActor
@Test func articleRendererBuildsWithExplicitIdentifier() {
    let navigator = TestNavigator()
    let article = SelfFixtures.article
    
    let view = DocCArticleView(
        article: article,
        navigator: navigator,
        identifier: "doc://example/documentation/custom"
    )
    
    #expect(view.reference.identifier == "doc://example/documentation/custom")
    _ = view.body
}

@MainActor
@Test func articleRendererBuildsWithExplicitReference() {
    let navigator = TestNavigator()
    let reference = SelfFixtures.articleReference
    let article = SelfFixtures.article
    
    let view = DocCArticleView(article: article, reference: reference, navigator: navigator)
    
    #expect(view.reference.identifier == reference.identifier)
    _ = view.body
}

@MainActor
@Test func articleRendererBuildsWithPage() {
    let navigator = TestNavigator()
    let page = SelfFixtures.articlePage
    
    let view = DocCArticleView(page: page, navigator: navigator)
    
    #expect(view.article.metadata.title == "Example Article")
    #expect(view.reference.identifier == SelfFixtures.articleReference.identifier)
    _ = view.body
}

@MainActor
@Test func homepageRendererBuildsWithMinimalNavigator() {
    let navigator = TestNavigator()
    let homepage = SelfFixtures.homepage
    
    let view = DocCHomepageView(homepage: homepage, navigator: navigator)
    
    #expect(view.homepage.metadata.title == "Example Homepage")
    #expect(view.navigator.deepLinkScheme.urlPrefix == "test-docs://")
    _ = view.body
}

@MainActor
@Test func frameworkRendererBuildsWithMinimalNavigator() {
    let navigator = TestNavigator()
    let frameworkSection = SelfFixtures.frameworkSection
    let framework = SelfFixtures.framework
    
    let view = DocCFrameworkView(framework: framework, frameworkSection: frameworkSection, navigator: navigator)
    
    #expect(view.framework.metadata.title == "Example Framework")
    #expect(view.navigator.deepLinkScheme.urlPrefix == "test-docs://")
    _ = view.body
}

@MainActor
@Test func frameworkRendererBuildsWithPage() {
    let navigator = TestNavigator()
    let page = SelfFixtures.frameworkPage
    
    let view = DocCFrameworkView(page: page, navigator: navigator)
    
    #expect(view.framework.metadata.title == "Example Framework")
    #expect(view.frameworkSection.destination.identifier == SelfFixtures.frameworkSection.destination.identifier)
    _ = view.body
}

private enum SelfFixtures {
    static let source = DocCSource(
        url: URL(string: "https://example.com/docs")!,
        index: DocCIndex(interfaceLanguages: [:])
    )
    
    static let articleReference = Reference(
        title: "Example Article",
        identifier: "doc://example/documentation/example/article",
        type: "article",
        role: .article,
        docCSite: source
    )
    
    static let articlePage = DocCArticlePage(article: article, reference: articleReference, source: source)
    
    static let article = Article(
        metadata: Article.Metadata(
            role: .article,
            roleHeading: "Article",
            color: nil,
            images: nil,
            title: "Example Article",
            platforms: nil
        ),
        topicSectionsStyle: nil,
        abstract: nil,
        primaryContentSections: nil,
        references: [:],
        legalNotices: nil,
        seeAlsoSections: nil,
        topicSections: nil,
        relationshipsSections: nil,
        sampleCodeDownload: nil,
        deprecationSummary: nil,
        betaSummary: nil,
        variants: nil,
        variantOverrides: nil
    )
    
    static let homepage = HomepageParser(
        metadata: HomepageParser.Metadata(title: "Example Homepage", role: .overview),
        sections: [],
        references: [:],
        legalNotices: nil
    )
    
    static let framework = Framework(
        topicSections: nil,
        metadata: Framework.Metadata(
            title: "Example Framework",
            role: .framework,
            images: nil,
            platforms: nil,
            modules: nil
        ),
        references: [:],
        legalNotices: nil,
        variants: nil
    )
    
    static let frameworkSection = AppleTechnologies.FrameworkSection(
        languages: ["swift"],
        title: "Example Framework",
        tags: [],
        destination: .init(
            type: "topic",
            isActive: true,
            identifier: "doc://example/documentation/example"
        ),
        legalNotices: nil,
        docCSite: source
    )
    
    static let frameworkPage = DocCFrameworkPage(framework: framework, frameworkSection: frameworkSection, source: source)
}
