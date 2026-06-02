import Foundation

/// Loads Apple Developer Documentation payloads.
public struct AppleDocsClient: Sendable {
    /// Base URL string for Apple Developer Documentation.
    public static let developerBaseURLString = DocCConstants.appleDeveloperBaseURLString
    /// Legacy tutorials data endpoint used by Apple-hosted DocC payloads.
    public static let basePath = URL(string: "\(developerBaseURLString)/tutorials/data")!
    
    /// Selected language used for Apple DocC payloads and variant patches.
    public var preferredLanguage: PreferredProgrammingLanguage
    
    /// Creates an Apple documentation client.
    ///
    /// - Parameter preferredLanguage: Language used for Apple DocC requests.
    public init(preferredLanguage: PreferredProgrammingLanguage = .swift) {
        self.preferredLanguage = preferredLanguage
    }
    
    /// Builds the Apple-hosted JSON endpoint for a documentation identifier.
    ///
    /// - Parameter identifier: A documentation identifier or URL-like identifier.
    /// - Returns: A JSON URL for the requested identifier, or `nil` if the identifier is invalid.
    public func jsonURL(for identifier: String) -> URL? {
        guard let identifier = URL(string: identifier) else {
            return nil
        }
        
        return Self.basePath
            .appending(path: identifier.path)
            .appendingPathExtension("json")
            .appending(queryItems: [.init(name: "language", value: preferredLanguage.rawValue)])
    }
    
    /// Loads the Apple Developer Documentation homepage payload.
    public func fetchHomepage() async throws -> HomepageParser {
        let url = URL(string: "\(Self.developerBaseURLString)/tutorials/data/documentation.json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(HomepageParser.self, from: data)
    }
    
    /// Loads the Apple technologies payload.
    public func fetchTechnologies() async throws -> AppleTechnologies {
        let url = URL(string: "\(Self.developerBaseURLString)/tutorials/data/documentation/technologies.json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(AppleTechnologies.self, from: data)
    }
    
    /// Fetches and decodes an Apple-hosted framework payload.
    public func fetchFramework(for identifier: String) async throws -> Framework {
        guard let url = jsonURL(for: identifier) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(Framework.self, from: data)
    }
    
    /// Fetches and decodes an Apple-hosted article, applying language-specific variant overrides.
    public func fetchArticle(for identifier: String) async throws -> Article {
        guard let url = jsonURL(for: identifier) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        var article = try JSONDecoder().decode(Article.self, from: data)
        DocCClient.applyVariantOverrides(to: &article, preferredLanguage: preferredLanguage)
        return article
    }
}
