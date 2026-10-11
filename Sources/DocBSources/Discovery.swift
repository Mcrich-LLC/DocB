// Turns a pasted URL into the sources it offers. Candidate base URLs are derived from the
// path; each is probed for the Apple catalog, then a static DocC index, then a DocC site too
// old to have one (build metadata plus a root page). The first hit is walked into one source
// or, for a catalog, many. No host names are hardcoded.

import Foundation
import DocCSchema

public enum Discovery {
    /// Path components that start a DocC page path; the prefix before one is the likely base.
    private static let pageMarkers: Set<String> = ["documentation", "tutorials"]
    /// Path components that start a DocC data or index path.
    private static let fileMarkers: Set<String> = ["data", "index"]

    /// Base URLs worth probing for a pasted URL, most specific first, ending at the host root.
    public static func candidates(for url: URL) -> [URL] {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return [] }
        components.query = nil
        components.fragment = nil
        var path = pathComponents(of: components)
        if let marker = path.firstIndex(where: { pageMarkers.contains($0.lowercased()) || fileMarkers.contains($0.lowercased()) }) {
            path.removeSubrange(marker...)
        }
        var result: [URL] = []
        while true {
            components.path = path.isEmpty ? "" : "/" + path.joined(separator: "/")
            if let candidate = components.url { result.append(candidate) }
            if path.isEmpty { break }
            path.removeLast()
        }
        return result
    }

    /// Finds the sources offered at a pasted URL: one per technology for a catalog, otherwise one.
    public static func discover(_ url: URL, transport: Transport = .urlSession()) async throws -> [Source] {
        var tried: [URL] = []
        for base in candidates(for: url) {
            let catalogURL = base.appending(path: "tutorials/data/documentation/technologies.json")
            tried.append(catalogURL)
            if let catalog = try await fetch(RenderNode.self, from: catalogURL, transport: transport) {
                return sources(base: base, catalog: catalog)
            }

            let indexURL = base.appending(path: "index/index.json")
            tried.append(indexURL)
            if let index = try await fetch(RenderIndex.self, from: indexURL, transport: transport) {
                return [source(base: base, index: index)]
            }

            let metadataURL = base.appending(path: "metadata.json")
            tried.append(metadataURL)
            if let metadata = try await fetch(BuildMetadata.self, from: metadataURL, transport: transport) {
                let root = rootPath(pasted: url, base: base) ?? "documentation/\(metadata.bundleDisplayName.lowercased())"
                let kind = Source.Kind.doccWithoutIndex(root: root)
                let rootURL = kind.dataURL(base: base, path: root)
                tried.append(rootURL)
                if let page = try await fetch(RenderNode.self, from: rootURL, transport: transport) {
                    return [source(base: base, root: root, metadata: metadata, page: page)]
                }
            }
        }
        throw DiscoveryError(tried: tried)
    }

    /// Fetches and decodes `url`, treating a non-2xx status or an undecodable body as a miss.
    private static func fetch<T: Decodable>(_ type: T.Type, from url: URL, transport: Transport) async throws -> T? {
        let (data, response) = try await transport.fetch(URLRequest(url: url))
        guard (200..<300).contains(response.statusCode) else { return nil }
        return try? RenderJSONDecoder.makeDecoder().decode(T.self, from: data)
    }

    /// The `documentation/<module>` path a pasted URL names below `base`, if it names one.
    static func rootPath(pasted: URL, base: URL) -> String? {
        guard let pastedComponents = URLComponents(url: pasted, resolvingAgainstBaseURL: true),
              let baseComponents = URLComponents(url: base, resolvingAgainstBaseURL: true) else { return nil }
        let path = pathComponents(of: pastedComponents)
        let basePath = pathComponents(of: baseComponents)
        guard path.count >= basePath.count + 2, Array(path.prefix(basePath.count)) == basePath else { return nil }
        let remainder = path.dropFirst(basePath.count).map { $0.lowercased() }
        guard let marker = remainder.first, pageMarkers.contains(marker) else { return nil }
        return remainder.prefix(2).joined(separator: "/")
    }

    /// Path components as written; hosts such as GitHub Pages are case sensitive, so nothing is lowercased here.
    private static func pathComponents(of components: URLComponents) -> [String] {
        components.path.split(separator: "/").map(String.init)
    }

    /// One source per module in the catalog. Nested entries fold into their module; the shortest path names it.
    static func sources(base: URL, catalog: RenderNode) -> [Source] {
        guard let technologies = catalog.sections.first(where: { $0.kind == .technologies }) as? TechnologiesRenderSection else {
            return []
        }
        struct Entry { var module: String; var depth: Int; var technology: TechnologiesRenderSection.Technology }
        var entries: [Entry] = []
        for technology in technologies.groups.flatMap(\.technologies) {
            guard case .reference(let identifier, _, _, _) = technology.destination,
                  let url = URL(string: identifier.identifier), url.scheme == "doc" else { continue }
            let components = url.pathComponents.filter { $0 != "/" }
            guard let start = components.firstIndex(where: { $0.lowercased() == "documentation" }),
                  components.count > start + 1 else { continue }
            let module = components[start + 1].lowercased()
            entries.append(Entry(module: module, depth: components.count - start - 1, technology: technology))
        }
        var byModule: [String: Entry] = [:]
        var order: [String] = []
        for entry in entries {
            if let existing = byModule[entry.module] {
                if entry.depth < existing.depth { byModule[entry.module] = entry }
            } else {
                byModule[entry.module] = entry
                order.append(entry.module)
            }
        }
        return order.compactMap { module in
            guard let technology = byModule[module]?.technology else { return nil }
            return Source(
                base: base,
                kind: .appleDeveloper(module: module),
                title: technology.title,
                languages: technology.languages,
                tags: technology.tags
            )
        }
    }

    /// The single source a static site offers, titled after its top-level modules.
    static func source(base: URL, index: RenderIndex) -> Source {
        let languages = index.interfaceLanguages.keys.sorted()
        var titles: [String] = []
        for language in languages {
            for node in index.interfaceLanguages[language] ?? [] where !titles.contains(node.title) {
                titles.append(node.title)
            }
        }
        return Source(
            base: base,
            kind: .docc,
            title: titles.isEmpty ? base.host() ?? base.absoluteString : titles.joined(separator: ", "),
            languages: languages
        )
    }

    /// The single source an index-less site offers, titled from its build metadata.
    static func source(base: URL, root: String, metadata: BuildMetadata, page: RenderNode) -> Source {
        Source(
            base: base,
            kind: .doccWithoutIndex(root: root),
            title: metadata.bundleDisplayName,
            languages: [page.identifier.sourceLanguage.id]
        )
    }
}
