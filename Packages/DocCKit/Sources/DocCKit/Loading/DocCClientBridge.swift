import Foundation

/// Selects the concrete documentation client for Apple-hosted or custom DocC content.
public enum DocCClientBridge: Sendable {
    /// Apple Developer Documentation client.
    case apple(AppleDocsClient)
    /// Source-ready custom DocC client.
    case docC(DocCClient)
    
    /// Creates a bridge for Apple Developer Documentation.
    ///
    /// - Parameter preferredLanguage: Language used for Apple DocC requests.
    public static func apple(preferredLanguage: PreferredProgrammingLanguage = .swift) -> Self {
        .apple(AppleDocsClient(preferredLanguage: preferredLanguage))
    }
    
    /// Creates a bridge for a custom DocC source.
    ///
    /// - Parameter source: Custom DocC source.
    public static func docC(_ source: DocCSource) -> Self {
        .docC(DocCClient(source: source))
    }
    
    /// Creates a bridge for a custom DocC source root URL.
    ///
    /// - Parameters:
    ///   - baseURL: Root URL for a DocC archive or static DocC site.
    ///   - overrideName: Optional display-name override stored on the resolved source.
    public static func docC(baseURL: URL, overrideName: String? = nil) async throws -> Self {
        .docC(try await DocCClient(baseURL: baseURL, overrideName: overrideName))
    }
    
    /// Builds the JSON endpoint for a documentation identifier.
    ///
    /// - Parameter identifier: A documentation identifier or URL-like identifier.
    /// - Returns: A JSON URL for the requested identifier, or `nil` if the identifier is invalid.
    public func jsonURL(for identifier: String) -> URL? {
        switch self {
        case .apple(let client):
            client.jsonURL(for: identifier)
        case .docC(let client):
            client.jsonURL(for: identifier)
        }
    }
    
    /// Fetches and decodes a framework payload for the selected source.
    public func fetchFramework(for identifier: String) async throws -> Framework {
        switch self {
        case .apple(let client):
            try await client.fetchFramework(for: identifier)
        case .docC(let client):
            try await client.fetchFramework(for: identifier)
        }
    }
    
    /// Fetches and decodes an article payload for the selected source.
    public func fetchArticle(for identifier: String, preferredLanguage: PreferredProgrammingLanguage = .swift) async throws -> Article {
        switch self {
        case .apple(let client):
            try await client.fetchArticle(for: identifier)
        case .docC(let client):
            try await client.fetchArticle(for: identifier, preferredLanguage: preferredLanguage)
        }
    }
}
