import Testing
import Foundation
@testable import DocCKit

@Test func exposesVersionMarker() {
    #expect(DocCKitMetadata.version == "0.1.0")
}

@Test func preferredProgrammingLanguageAcceptsLegacyObjectiveCToken() {
    #expect(PreferredProgrammingLanguage(rawValue: "occ") == .objectivec)
    #expect(PreferredProgrammingLanguage.objectivec.jsonCodingValue == "occ")
}

@Test func clientBuildsCustomSourceJSONURL() {
    let source = DocCSource(
        url: URL(string: "https://example.com/docs")!,
        index: DocCIndex(interfaceLanguages: [:])
    )
    
    let url = DocCClient.jsonURL(for: "doc://example/documentation/MyKit/MyType", source: source)
    
    #expect(url?.absoluteString == "https://example.com/docs/data/documentation/mykit/mytype.json")
}

@Test func sourceReadyClientBuildsCustomSourceJSONURL() {
    let source = DocCSource(
        url: URL(string: "https://example.com/docs")!,
        index: DocCIndex(interfaceLanguages: [:])
    )
    let client = DocCClient(source: source)
    
    let url = client.jsonURL(for: "doc://example/documentation/MyKit/MyType")
    
    #expect(url?.absoluteString == "https://example.com/docs/data/documentation/mykit/mytype.json")
}

@Test func clientLoadsSourceFromBaseURL() async throws {
    let fixture = try DocCClientFixture()
    defer { fixture.remove() }
    
    let client = try await DocCClient(baseURL: fixture.rootURL, overrideName: "Fixture Docs")
    
    #expect(client.source.url == fixture.rootURL)
    #expect(client.source.overrideName == "Fixture Docs")
    #expect(client.source.index.interfaceLanguages["swift"]?.first?.title == "Example Framework")
    #expect(client.source.index.interfaceLanguages["swift"]?.first?.path == fixture.frameworkIdentifier)
}

@Test func clientLoadsIndexFromExplicitURL() async throws {
    let fixture = try DocCClientFixture()
    defer { fixture.remove() }
    
    let index = try await DocCClient.fetchIndex(from: fixture.indexURL)
    
    #expect(index.interfaceLanguages["swift"]?.first?.title == "Example Framework")
    #expect(index.interfaceLanguages["swift"]?.first?.path == fixture.frameworkIdentifier)
}

@Test func clientFetchesArticlePageWithRenderReadyReference() async throws {
    let fixture = try DocCClientFixture()
    defer { fixture.remove() }
    let client = DocCClient(source: fixture.source)
    
    let page = try await client.fetchArticlePage(for: fixture.articleIdentifier)
    
    #expect(page.article.metadata.title == "Example Article")
    #expect(page.reference.identifier == fixture.articleIdentifier)
    #expect(page.reference.title == "Example Article")
    #expect(page.reference.role == .article)
    #expect(page.reference.roleHeading == "Article")
    #expect(page.reference.docCSite == fixture.source)
    #expect(page.source == fixture.source)
}

@Test func symbolKindPrefersReferenceRoleHeadingOverTitleHeuristics() {
    let reference = Reference(
        title: "UIApplication",
        identifier: "doc://example/documentation/uikit/uiapplication",
        type: "symbol",
        role: .symbol,
        roleHeading: "Class"
    )

    #expect(SidebarSearchSymbolKind(reference: reference, title: "UIApplication") == .classSymbol)
}

@Test func symbolKindNormalizesRoleHeadingVariants() {
    let expectations: [(String, SidebarSearchSymbolKind)] = [
        ("Article", .article),
        ("Guide", .article),
        ("Sample Code", .article),
        ("Class", .classSymbol),
        ("Collection", .collection),
        ("Collection Group", .collectionGroup),
        ("Enumeration", .enumeration),
        ("Enum", .enumeration),
        ("Enumeration Case", .enumerationCase),
        ("Framework", .framework),
        ("Module", .framework),
        ("Function", .function),
        ("Operator", .function),
        ("Initializer", .initializer),
        ("Macro", .macro),
        ("Instance Method", .method),
        ("Type Method", .method),
        ("Static Method", .method),
        ("Class Method", .method),
        ("Instance Property", .property),
        ("Type Property", .property),
        ("Static Property", .property),
        ("Class Property", .property),
        ("Protocol", .protocolSymbol),
        ("Structure", .structure),
        ("Struct", .structure),
        ("Type Alias", .typeAlias),
        ("Associated Type", .typeAlias),
        ("Variable", .variable),
        ("Global Variable", .variable),
        ("Constant", .variable),
        ("HTTP Request", .method),
        ("REST Request", .method),
        ("Web Service Endpoint", .method)
    ]

    for (roleHeading, symbolKind) in expectations {
        #expect(SidebarSearchSymbolKind(roleHeading: roleHeading) == symbolKind)
        #expect(SidebarSearchSymbolKind(roleHeading: "  \(roleHeading.uppercased())  ") == symbolKind)
    }

    #expect(SidebarSearchSymbolKind(roleHeading: "type-method") == .method)
    #expect(SidebarSearchSymbolKind(roleHeading: "associated_type") == .typeAlias)
}

@Test func symbolKindDoesNotClassifyControllerSuffixAsClassWithoutMetadata() {
    #expect(SidebarSearchSymbolKind(title: "UIAlertController", path: "/documentation/uikit/uialertcontroller", type: "symbol") == .structure)
}

@Test func clientFetchesFrameworkPageWithSourceSection() async throws {
    let fixture = try DocCClientFixture()
    defer { fixture.remove() }
    let client = DocCClient(source: fixture.source)
    
    let page = try await client.fetchFrameworkPage(for: fixture.frameworkIdentifier)
    
    #expect(page.framework.metadata.title == "Example Framework")
    #expect(page.frameworkSection.title == "Example Framework")
    #expect(page.frameworkSection.destination.identifier == fixture.frameworkIdentifier)
    #expect(page.frameworkSection.docCSite == fixture.source)
    #expect(page.source == fixture.source)
}

@Test func deepLinkSchemeNormalizesBareSchemeNames() {
    let scheme = DocCDeepLinkScheme("example-docs")
    
    #expect(scheme.urlPrefix == "example-docs://")
    #expect(scheme.urlString(forDocIdentifier: "doc://example/documentation/MyKit/MyType") == "example-docs://example/documentation/MyKit/MyType")
}

@Test func deepLinkSchemePreservesURLPrefixes() {
    let scheme = DocCDeepLinkScheme("example-docs://")
    
    #expect(scheme.urlPrefix == "example-docs://")
    #expect(scheme.urlString(forDocIdentifier: "doc://example/documentation/MyKit/MyType") == "example-docs://example/documentation/MyKit/MyType")
}

@Test func deepLinkSchemeFallsBackToDocSchemeForEmptyInput() {
    let scheme = DocCDeepLinkScheme(" ")
    
    #expect(scheme.urlPrefix == "doc://")
    #expect(scheme.urlString(forDocIdentifier: "doc://example/documentation/MyKit/MyType") == "doc://example/documentation/MyKit/MyType")
}

@Test func deepLinkSchemePrefersExplicitInfoDictionaryKey() {
    let infoDictionary: [String: Any] = [
        "DocCKitDeepLinkScheme": "explicit-docs",
        "CFBundleURLTypes": [
            [
                "CFBundleURLName": "com.example.docs",
                "CFBundleURLSchemes": ["bundle-docs"]
            ]
        ]
    ]
    
    #expect(DocCDeepLinkScheme.preferredScheme(in: infoDictionary, bundleIdentifier: "com.example.docs") == "explicit-docs")
}

@Test func deepLinkSchemePrefersBundleIdentifierURLType() {
    let infoDictionary: [String: Any] = [
        "CFBundleURLTypes": [
            [
                "CFBundleURLName": "doc",
                "CFBundleURLSchemes": ["doc"]
            ],
            [
                "CFBundleURLName": "com.example.docs",
                "CFBundleURLSchemes": ["example-docs"]
            ]
        ]
    ]
    
    #expect(DocCDeepLinkScheme.preferredScheme(in: infoDictionary, bundleIdentifier: "com.example.docs.debug") == "example-docs")
}

@Test func deepLinkSchemeFallsBackToNonDocURLType() {
    let infoDictionary: [String: Any] = [
        "CFBundleURLTypes": [
            [
                "CFBundleURLName": "doc",
                "CFBundleURLSchemes": ["doc"]
            ],
            [
                "CFBundleURLName": "shared-docs",
                "CFBundleURLSchemes": ["shared-docs"]
            ]
        ]
    ]
    
    #expect(DocCDeepLinkScheme.preferredScheme(in: infoDictionary, bundleIdentifier: nil) == "shared-docs")
}

@Test func appleClientBuildsAppleJSONURLWithLanguage() {
    let client = AppleDocsClient(preferredLanguage: .objectivec)
    
    let url = client.jsonURL(for: "doc://com.apple.documentation/documentation/swift/string")
    
    #expect(url?.absoluteString == "https://developer.apple.com/tutorials/data/documentation/swift/string.json?language=objc")
}

@Test func bridgeBuildsURLsForAppleAndCustomSources() {
    let source = DocCSource(
        url: URL(string: "https://example.com/docs")!,
        index: DocCIndex(interfaceLanguages: [:])
    )
    
    let appleURL = DocCClientBridge
        .apple(preferredLanguage: .objectivec)
        .jsonURL(for: "doc://com.apple.documentation/documentation/swift/string")
    let customURL = DocCClientBridge
        .docC(source)
        .jsonURL(for: "doc://example/documentation/MyKit/MyType")
    
    #expect(appleURL?.absoluteString == "https://developer.apple.com/tutorials/data/documentation/swift/string.json?language=objc")
    #expect(customURL?.absoluteString == "https://example.com/docs/data/documentation/mykit/mytype.json")
}

private struct DocCClientFixture {
    let rootURL: URL
    let indexURL: URL
    let index: DocCIndex
    let source: DocCSource
    let articleIdentifier = "doc://example/documentation/MyKit/MyType"
    let frameworkIdentifier = "doc://example/documentation/MyKit"
    
    init() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appending(path: "DocCKitTests-\(UUID().uuidString)")
        self.rootURL = rootURL
        self.indexURL = rootURL.appending(path: "index/index.json")
        
        self.index = DocCIndex(interfaceLanguages: [
            "swift": [
                .init(title: "Example Framework", path: frameworkIdentifier, type: "module")
            ]
        ])
        self.source = DocCSource(url: rootURL, index: index)
        
        try writeFixtureFiles()
    }
    
    func remove() {
        try? FileManager.default.removeItem(at: rootURL)
    }
    
    private func writeFixtureFiles() throws {
        try FileManager.default.createDirectory(
            at: indexURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(index).write(to: indexURL)
        
        let documentationRootURL = rootURL.appending(path: "data/documentation")
        let frameworkDataRootURL = documentationRootURL.appending(path: "mykit")
        try FileManager.default.createDirectory(at: frameworkDataRootURL, withIntermediateDirectories: true)
        try JSONEncoder().encode(Self.article).write(to: frameworkDataRootURL.appending(path: "mytype.json"))
        try JSONEncoder().encode(Self.framework).write(to: documentationRootURL.appending(path: "mykit.json"))
    }
    
    private static let article = Article(
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
    
    private static let framework = Framework(
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
}
