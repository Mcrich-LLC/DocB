import Foundation

/// Loads custom DocC indexes and page payloads.
public struct DocCClient: Sendable {
    /// Source context used for all instance loading operations.
    public private(set) var source: DocCSource
    
    /// Creates a custom DocC client by loading the source index from the source root URL.
    ///
    /// - Parameters:
    ///   - baseURL: Root URL for a DocC archive or static DocC site.
    ///   - overrideName: Optional display-name override stored on the resolved source.
    public init(baseURL: URL, overrideName: String? = nil) async throws {
        let index = try await Self.fetchIndex(baseURL: baseURL)
        self.source = DocCSource(url: baseURL, overrideName: overrideName, index: index)
    }
    
    /// Creates a custom DocC client from an already resolved source.
    ///
    /// - Parameter source: Source context used for loading article and framework payloads.
    public init(source: DocCSource) {
        self.source = source
    }
    
    /// Builds the JSON endpoint for a documentation identifier.
    ///
    /// - Parameter identifier: A documentation identifier or URL-like identifier.
    /// - Returns: A JSON URL for the requested identifier, or `nil` if the identifier is invalid.
    public func jsonURL(for identifier: String) -> URL? {
        Self.jsonURL(for: identifier, source: source)
    }
    
    /// Builds the JSON endpoint for a documentation identifier.
    ///
    /// - Parameters:
    ///   - identifier: A documentation identifier or URL-like identifier.
    ///   - source: Custom DocC source context.
    /// - Returns: A JSON URL for the requested identifier, or `nil` if the identifier is invalid.
    public static func jsonURL(for identifier: String, source: DocCSource) -> URL? {
        var identifier = identifier.lowercased()
        if let index = identifier.firstRange(of: "/documentation") {
            identifier = identifier.suffix(from: index.lowerBound).lowercased()
        }
        
        return source.url
            .appending(path: "data")
            .appending(path: identifier)
            .appendingPathExtension("json")
    }
    
    /// Resolves the final destination URL after redirects.
    ///
    /// - Parameter url: The URL to request.
    /// - Returns: The final URL returned by the server response.
    public static func redirectedURL(for url: URL) async throws -> URL {
        let (_, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, let url = httpResponse.url else {
            throw URLError(.badServerResponse)
        }
        
        return url
    }
    
    /// Loads a custom DocC source index from the source root URL.
    ///
    /// - Parameter baseURL: Root URL for a DocC archive/site.
    public static func fetchIndex(baseURL: URL) async throws -> DocCIndex {
        try await fetchIndex(from: baseURL.appending(path: "index/index.json"))
    }
    
    /// Loads a DocC index from an explicit URL.
    ///
    /// - Parameter indexURL: URL for the source's `index/index.json` payload.
    public static func fetchIndex(from indexURL: URL) async throws -> DocCIndex {
        let data = try await data(from: indexURL)
        return try JSONDecoder().decode(DocCIndex.self, from: data)
    }
    
    /// Fetches and decodes a framework payload for a documentation identifier.
    ///
    /// - Parameter identifier: A documentation identifier or URL-like identifier.
    /// - Returns: Decoded framework payload for the client's source.
    public func fetchFramework(for identifier: String) async throws -> Framework {
        guard let url = jsonURL(for: identifier) else {
            throw URLError(.badURL)
        }
        
        let data = try await Self.data(from: url)
        return try JSONDecoder().decode(Framework.self, from: data)
    }
    
    /// Fetches and decodes a documentation article, applying language-specific variant overrides.
    ///
    /// - Parameters:
    ///   - identifier: A documentation identifier or URL-like identifier.
    ///   - preferredLanguage: Preferred language used for variant override patches.
    /// - Returns: Decoded article payload for the client's source.
    public func fetchArticle(for identifier: String, preferredLanguage: PreferredProgrammingLanguage = .swift) async throws -> Article {
        guard let url = jsonURL(for: identifier) else {
            throw URLError(.badURL)
        }
        
        let data = try await Self.data(from: url)
        var article = try JSONDecoder().decode(Article.self, from: data)
        Self.applyVariantOverrides(to: &article, preferredLanguage: preferredLanguage)
        return article
    }
    
    /// Fetches a render-ready article page for a documentation identifier.
    ///
    /// - Parameters:
    ///   - identifier: A documentation identifier or URL-like identifier.
    ///   - preferredLanguage: Preferred language used for variant override patches.
    /// - Returns: An article, synthesized reference, and source ready for rendering.
    public func fetchArticlePage(for identifier: String, preferredLanguage: PreferredProgrammingLanguage = .swift) async throws -> DocCArticlePage {
        let article = try await fetchArticle(for: identifier, preferredLanguage: preferredLanguage)
        let reference = Reference(
            title: article.metadata.title,
            identifier: identifier,
            type: "article",
            role: article.metadata.role,
            docCSite: source
        )
        
        return DocCArticlePage(article: article, reference: reference, source: source)
    }
    
    /// Fetches a render-ready framework page for a documentation identifier.
    ///
    /// - Parameter identifier: A documentation identifier or URL-like identifier.
    /// - Returns: A framework, framework section, and source ready for rendering.
    public func fetchFrameworkPage(for identifier: String) async throws -> DocCFrameworkPage {
        let framework = try await fetchFramework(for: identifier)
        let frameworkSection = source.allFrameworkSections.first { section in
            Self.identifiersMatch(section.destination.identifier, identifier)
        } ?? AppleTechnologies.FrameworkSection(
            languages: [],
            title: framework.metadata.title,
            tags: [],
            destination: .init(type: "topic", isActive: true, identifier: identifier),
            legalNotices: framework.legalNotices,
            docCSite: source
        )
        
        return DocCFrameworkPage(framework: framework, frameworkSection: frameworkSection, source: source)
    }
    
    /// Applies declaration overrides matching the client's preferred language.
    ///
    /// - Parameters:
    ///   - article: Article mutated in place with matching variant declarations.
    ///   - preferredLanguage: Preferred language used to choose variant patches.
    public static func applyVariantOverrides(to article: inout Article, preferredLanguage: PreferredProgrammingLanguage) {
        for variant in article.variantOverrides ?? [] where variant.patch.contains(where: {
            ($0.value?.declarations ?? []).contains {
                $0.languages.contains(preferredLanguage.jsonCodingValue)
            }
        }) {
            for patch in variant.patch where (patch.value?.declarations ?? []).contains(where: { $0.languages.contains(preferredLanguage.jsonCodingValue) }) {
                let pathComponents = patch.path.split(separator: "/")
                if pathComponents.contains(where: { $0 == "primaryContentSections" }),
                   let indexString = pathComponents.last,
                   let index = Int(indexString) {
                    article.primaryContentSections?[index].declarations = patch.value?.declarations
                }
            }
        }
    }
    
    private static func data(from url: URL) async throws -> Data {
        if url.isFileURL {
            return try Data(contentsOf: url)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
    
    private static func identifiersMatch(_ lhs: String, _ rhs: String) -> Bool {
        guard let lhsURL = URL(string: lhs), let rhsURL = URL(string: rhs) else {
            return lhs.lowercased() == rhs.lowercased()
        }
        
        return lhsURL.path().lowercased() == rhsURL.path().lowercased()
    }
}
