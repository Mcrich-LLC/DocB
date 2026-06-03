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

    /// Loads and merges search indexes for every active Apple technology.
    ///
    /// - Parameter technologies: Apple technologies payload used to discover per-framework indexes.
    /// - Returns: A merged DocC index containing entries from each available framework index.
    public func fetchIndex(for technologies: AppleTechnologies) async throws -> DocCIndex {
        let indexURLs = Self.indexURLs(for: technologies)
        guard !indexURLs.isEmpty else {
            return DocCIndex(interfaceLanguages: [:])
        }

        let indexes = await withTaskGroup(of: DocCIndex?.self, returning: [DocCIndex].self) { group in
            var iterator = indexURLs.makeIterator()
            let maximumConcurrentRequests = 4

            for _ in 0..<min(maximumConcurrentRequests, indexURLs.count) {
                guard let url = iterator.next() else { break }
                group.addTask {
                    await Self.fetchIndexIfAvailable(from: url)
                }
            }

            var indexes: [DocCIndex] = []
            while let index = await group.next() {
                if let index {
                    indexes.append(index)
                }

                if let url = iterator.next() {
                    group.addTask {
                        await Self.fetchIndexIfAvailable(from: url)
                    }
                }
            }

            return indexes
        }

        return Self.mergedIndex(from: indexes)
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

    private static func indexURLs(for technologies: AppleTechnologies) -> [URL] {
        let modules = (technologies.groups ?? [])
            .flatMap(\.technologies)
            .filter(\.destination.isActive)
            .compactMap { technology -> String? in
                guard let url = URL(string: technology.destination.identifier) else {
                    return nil
                }

                return url.pathComponents.dropFirst(2).first?.lowercased()
            }

        return Set(modules)
            .sorted()
            .map { module in
                Self.basePath
                    .appending(path: "index")
                    .appending(path: module)
                    .appendingPathExtension("json")
            }
    }

    private static func fetchIndexIfAvailable(from url: URL) async -> DocCIndex? {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse,
               !(200..<300).contains(httpResponse.statusCode) {
                return nil
            }

            return try JSONDecoder().decode(DocCIndex.self, from: data)
        } catch {
            return nil
        }
    }

    private static func mergedIndex(from indexes: [DocCIndex]) -> DocCIndex {
        var interfaceLanguages: [String : [DocCIndex.InterfaceLanguage]] = [:]
        var includedArchiveIdentifiers: Set<String> = []

        for index in indexes {
            for (language, entries) in index.interfaceLanguages {
                interfaceLanguages[language, default: []].append(contentsOf: entries)
            }

            for identifier in index.includedArchiveIdentifiers ?? [] {
                includedArchiveIdentifiers.insert(identifier)
            }
        }

        return DocCIndex(
            interfaceLanguages: interfaceLanguages,
            includedArchiveIdentifiers: includedArchiveIdentifiers.isEmpty ? nil : includedArchiveIdentifiers.sorted()
        )
    }
}
