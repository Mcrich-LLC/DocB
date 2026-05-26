//
//  SearchSymbolResolver.swift
//  DocB
//
//  Created by Codex on 5/26/26.
//

import DocCKit
import Foundation

/// Resolves Xcode-style documentation symbol badges from cached DocC metadata.
public enum SearchSymbolResolver {
    /// Returns whether a best-effort kind should be refined with richer cached metadata.
    ///
    /// - Parameter symbolKind: Initial symbol kind from lightweight search/index data.
    /// - Returns: `true` when the kind is ambiguous enough to benefit from refinement.
    public static func shouldRefine(_ symbolKind: SidebarSearchSymbolKind) -> Bool {
        switch symbolKind {
        case .structure:
            true
        default:
            false
        }
    }

    /// Resolves a symbol kind from a custom source's persisted DocC index.
    ///
    /// - Parameters:
    ///   - site: Custom DocC source containing the persisted index.
    ///   - path: Relative DocC path to match.
    ///   - title: Display title used when the matched index entry does not include one.
    /// - Returns: The indexed symbol kind, if a matching index entry exists.
    public static func symbolKind(in site: DocCSource, matchingPath path: String, title: String) -> SidebarSearchSymbolKind? {
        guard let normalizedPath = normalizedDocumentationPath(path) else {
            return nil
        }

        return symbolKind(in: site, matchingAny: [normalizedPath], title: title)
    }

    /// Resolves a symbol kind from a custom source's persisted DocC index.
    ///
    /// - Parameters:
    ///   - site: Custom DocC source containing the persisted index.
    ///   - reference: Reference whose URL or identifier should match an index entry.
    ///   - title: Display title used when the matched index entry does not include one.
    /// - Returns: The indexed symbol kind, if a matching index entry exists.
    public static func symbolKind(in site: DocCSource, matching reference: Reference, title: String) -> SidebarSearchSymbolKind? {
        let paths = [
            reference.url,
            reference.identifier
        ].compactMap(normalizedDocumentationPath)

        return symbolKind(in: site, matchingAny: paths, title: title)
    }

    /// Resolves a symbol kind for a DocC reference, preferring the source index before reference metadata.
    ///
    /// - Parameters:
    ///   - reference: DocC reference to classify.
    ///   - title: Display title used when metadata is incomplete.
    ///   - site: Optional custom DocC source containing the persisted index.
    /// - Returns: The resolved symbol kind.
    public static func symbolKind(for reference: Reference, title: String, site: DocCSource?) -> SidebarSearchSymbolKind {
        if let site,
           let indexedSymbolKind = symbolKind(in: site, matching: reference, title: title)
        {
            return indexedSymbolKind
        }

        return SidebarSearchSymbolKind(reference: reference, title: title)
    }

    /// Resolves a symbol kind for a search result using cached metadata first, then article metadata.
    ///
    /// - Parameters:
    ///   - result: Search result to refine.
    ///   - documentationViewModel: Documentation source model with loaded framework/article caches.
    /// - Returns: Refined symbol kind, if richer metadata is available.
    @MainActor
    public static func refinedSymbolKind(
        for result: SidebarSearchReferenceResult,
        documentationViewModel: DocumentationViewModel
    ) async -> SidebarSearchSymbolKind? {
        if let cachedSymbolKind = cachedSymbolKind(for: result, documentationViewModel: documentationViewModel) {
            return cachedSymbolKind
        }

        do {
            let reference = result.reference(deepLinkScheme: DocCDeepLinkScheme.mainBundle ?? DocCDeepLinkScheme(Constants.deeplinkScheme))
            let article = try await documentationViewModel.fetchArticle(for: reference.identifier, site: result.site)
            return SidebarSearchSymbolKind(roleHeading: article.metadata.roleHeading)
        } catch {
            return nil
        }
    }

    /// Normalizes URLs and DocC paths for path-based metadata matching.
    ///
    /// - Parameter value: URL or relative path.
    /// - Returns: Lowercased URL path or lowercased value.
    public static func normalizedDocumentationPath(_ value: String?) -> String? {
        guard let value, !value.isEmpty else {
            return nil
        }

        if let url = URL(string: value), !url.path().isEmpty {
            return url.path().lowercased()
        }

        return value.lowercased()
    }

    @MainActor
    private static func cachedSymbolKind(
        for result: SidebarSearchReferenceResult,
        documentationViewModel: DocumentationViewModel
    ) -> SidebarSearchSymbolKind? {
        if let indexedSymbolKind = symbolKind(in: result.site, matchingPath: result.path, title: result.title) {
            return indexedSymbolKind
        }

        let targetPath = normalizedDocumentationPath(result.path)

        for framework in documentationViewModel.frameworks.values {
            guard let reference = framework.references.values.first(where: { reference in
                normalizedDocumentationPath(reference.url) == targetPath ||
                normalizedDocumentationPath(reference.identifier) == targetPath
            }) else {
                continue
            }

            return symbolKind(for: reference, title: result.title, site: reference.docCSite ?? result.site)
        }

        return nil
    }

    private static func symbolKind(in site: DocCSource, matchingAny paths: [String], title: String) -> SidebarSearchSymbolKind? {
        guard !paths.isEmpty else {
            return nil
        }

        for language in site.index.interfaceLanguages.values.flatMap({ $0 }) {
            if let match = symbolKind(in: language, matchingAny: paths, title: title) {
                return match
            }
        }

        return nil
    }

    private static func symbolKind(
        in language: DocCIndex.InterfaceLanguage,
        matchingAny paths: [String],
        title: String
    ) -> SidebarSearchSymbolKind? {
        if let path = language.path,
           let normalizedPath = normalizedDocumentationPath(path),
           paths.contains(normalizedPath)
        {
            return SidebarSearchSymbolKind(title: language.title, path: path, type: language.type)
        }

        for child in language.children ?? [] {
            if let match = symbolKind(in: child, matchingAny: paths, title: title) {
                return match
            }
        }

        return nil
    }
}
