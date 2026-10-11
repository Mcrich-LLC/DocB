// Navigator sync: revalidate each source's index with a conditional GET (or crawl an
// index-less site), swap the navigator rows in one transaction, purge the pages that swap
// orphaned, and enqueue pages for offline sources. `sync` runs that for every source, then
// drains the page queue, streaming events as it goes.

import Foundation
import GRDB
import DocCSchema
import DocBSources

extension Library {
    /// Syncs every source, or just `only`, then drains pages until nothing is left or `budget` runs out.
    /// `force` re-downloads navigators even when fresh or unchanged, so their trees are rebuilt.
    public nonisolated func sync(only: Source? = nil, budget: Duration? = nil, force: Bool = false) -> AsyncThrowingStream<SyncEvent, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await self.runSync(only: only, budget: budget, force: force) { continuation.yield($0) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func runSync(only: Source?, budget: Duration?, force: Bool, emit: @escaping @Sendable (SyncEvent) -> Void) async throws {
        let deadline = budget.map { configuration.now().addingTimeInterval(TimeInterval($0.components.seconds)) }
        let onlyID = only?.storeID
        let rows = try await writer.read { db in
            try onlyID.map { try SourceRow.filter(key: $0).fetchAll(db) } ?? SourceRow.fetchAll(db)
        }
        for row in rows {
            try Task.checkCancellation()
            let source = try row.source
            do {
                try await syncNavigator(row, source: source, force: force, emit: emit)
            } catch {
                emit(.navigatorFailed(source, String(describing: error)))
            }
        }
        try await flagStalePages()
        try await drain(deadline: deadline, emit: emit)
        let remaining = try await writer.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM page WHERE status = 'pending' OR revalidate") ?? 0
        }
        emit(.remaining(remaining))
        emit(.finished)
    }

    // MARK: Navigator

    func syncNavigator(_ row: SourceRow, source: Source, force: Bool, emit: @escaping @Sendable (SyncEvent) -> Void) async throws {
        let now = configuration.now()
        if !force, let syncedAt = row.indexSyncedAt, now.timeIntervalSince(syncedAt) < configuration.staleAfter {
            return
        }
        switch source.navigator {
        case .index(let url):
            var request = URLRequest(url: url)
            if !force, let etag = row.indexETag {
                request.setValue(etag, forHTTPHeaderField: "If-None-Match")
            }
            let (data, response) = try await transport.fetch(request)
            if response.statusCode == 304 {
                try await writer.write { db in
                    try db.execute(sql: "UPDATE source SET indexSyncedAt = ? WHERE id = ?", arguments: [now, row.id])
                }
                emit(.navigatorUnchanged(source))
                return
            }
            guard (200..<300).contains(response.statusCode) else {
                throw StoreError.navigatorUnavailable(source, status: response.statusCode)
            }
            let index = try RenderJSONDecoder.makeDecoder().decode(RenderIndex.self, from: data)
            let tree = Library.tree(from: index, source: source)
            try await swap(row: row, source: source, tree: tree, etag: response.value(forHTTPHeaderField: "ETag"), now: now)
            emit(.navigatorUpdated(source))
        case .crawl(let root):
            let tree = try await crawl(source: source, root: root, emit: emit)
            try await swap(row: row, source: source, tree: tree, etag: nil, now: now)
            emit(.navigatorUpdated(source))
        }
    }

    /// A navigator subtree before it has row identifiers.
    struct TreeNode {
        var language: String
        var title: String
        var path: String?
        var type: String
        var deprecated = false
        var beta = false
        var external = false
        var icon: String?
        var children: [TreeNode] = []
    }

    static func tree(from index: RenderIndex, source: Source) -> [TreeNode] {
        func convert(_ node: RenderIndex.Node, language: String) -> TreeNode {
            // `isExternal` marks cross-technology entries too, and those have ordinary base-relative
            // paths; the resolver itself returns nil for a path on another host.
            let path = node.path.flatMap { source.location(for: $0)?.path }
            return TreeNode(
                language: language,
                title: node.title,
                path: path,
                type: node.type ?? "groupMarker",
                deprecated: node.isDeprecated,
                beta: node.isBeta,
                external: node.isExternal,
                icon: node.icon?.identifier,
                children: (node.children ?? []).map { convert($0, language: language) }
            )
        }
        return index.interfaceLanguages.keys.sorted().flatMap { language in
            (index.interfaceLanguages[language] ?? []).map { convert($0, language: language) }
        }
    }

    /// Replaces a source's navigator, purges pages the swap orphaned, and enqueues for offline sources.
    func swap(row: SourceRow, source: Source, tree: [TreeNode], etag: String?, now: Date) async throws {
        let id = row.id
        let base = row.base
        try await writer.write { db in
            let oldPaths = try Set(String.fetchAll(db, sql: "SELECT path FROM navigator WHERE sourceID = ? AND path IS NOT NULL", arguments: [id]))
            try db.execute(sql: "DELETE FROM navigator WHERE sourceID = ?", arguments: [id])

            var newPaths: Set<String> = []
            func insert(_ node: TreeNode, parentID: Int64?, position: Int) throws {
                var record = NavigatorRow(sourceID: id, language: node.language, parentID: parentID, position: position, title: node.title, path: node.path, type: node.type, deprecated: node.deprecated, beta: node.beta, external: node.external, icon: node.icon)
                try record.insert(db)
                if let path = node.path { newPaths.insert(path) }
                for (index, child) in node.children.enumerated() {
                    try insert(child, parentID: record.id, position: index)
                }
            }
            for (index, node) in tree.enumerated() {
                try insert(node, parentID: nil, position: index)
            }

            try Library.purge(db, base: base, paths: oldPaths.subtracting(newPaths))
            try db.execute(sql: "UPDATE source SET indexETag = ?, indexSyncedAt = ? WHERE id = ?", arguments: [etag, now, id])

            if row.offline {
                try Library.enqueue(db, base: base, paths: newPaths)
                // The index changed, so any page may have changed under an unchanged title.
                for path in newPaths {
                    try db.execute(sql: "UPDATE page SET revalidate = 1 WHERE base = ? AND path = ? AND status = 'fetched'", arguments: [base, path])
                }
            }
        }
    }

    // MARK: Crawl

    /// Builds a navigator for an index-less site by walking topic sections from the root, storing each page on the way.
    func crawl(source: Source, root: PageLocation, emit: @escaping @Sendable (SyncEvent) -> Void) async throws -> [TreeNode] {
        var visited: Set<String> = []
        func visit(_ location: PageLocation, fallbackTitle: String) async throws -> TreeNode? {
            guard visited.insert(location.path).inserted else { return nil }
            try Task.checkCancellation()
            let node: RenderNode
            do {
                node = try await page(at: location)
            } catch let error as StoreError {
                // Old sites have dead links; keep the entry so the tree matches the site, but stop there.
                emit(.pageFailed(location, String(describing: error)))
                return TreeNode(language: "swift", title: fallbackTitle, path: location.path, type: "symbol")
            }
            var tree = TreeNode(
                language: node.identifier.sourceLanguage.id,
                title: node.metadata.title ?? location.path,
                path: location.path,
                type: node.metadata.role ?? node.kind.rawValue
            )
            for section in node.topicSections {
                var group = TreeNode(language: tree.language, title: section.title ?? "", path: nil, type: "groupMarker")
                for identifier in section.identifiers {
                    guard let reference = node.references[identifier] as? TopicRenderReference,
                          let childLocation = source.location(for: reference.url),
                          let child = try await visit(childLocation, fallbackTitle: reference.title) else { continue }
                    group.children.append(child)
                }
                if group.title.isEmpty {
                    tree.children.append(contentsOf: group.children)
                } else if !group.children.isEmpty {
                    tree.children.append(group)
                }
            }
            return tree
        }
        guard let rootNode = try await visit(root, fallbackTitle: source.title) else { return [] }
        return [rootNode]
    }

    // MARK: Reading the navigator

    /// A source's page tree in one language, or in the first language it has when it lacks
    /// that one: a REST API is `data` only and should not come up empty for a Swift reader.
    public func navigator(for source: Source, language: String) async throws -> [NavigatorNode] {
        let id = source.storeID
        let base = source.base
        return try await writer.read { db in
            var rows = try NavigatorRow
                .filter(Column("sourceID") == id && Column("language") == language)
                .order(Column("position"))
                .fetchAll(db)
            if rows.isEmpty, let fallback = try String.fetchOne(db, sql: "SELECT language FROM navigator WHERE sourceID = ? ORDER BY language LIMIT 1", arguments: [id]) {
                rows = try NavigatorRow
                    .filter(Column("sourceID") == id && Column("language") == fallback)
                    .order(Column("position"))
                    .fetchAll(db)
            }
            let byParent = Dictionary(grouping: rows, by: { $0.parentID })
            func build(_ row: NavigatorRow) -> NavigatorNode {
                NavigatorNode(
                    id: row.id ?? 0,
                    title: row.title,
                    location: row.path.map { PageLocation(base: base, path: $0) },
                    type: row.type,
                    isDeprecated: row.deprecated,
                    isBeta: row.beta,
                    isExternal: row.external,
                    icon: row.icon,
                    children: (byParent[row.id] ?? []).map(build)
                )
            }
            return (byParent[nil] ?? []).map(build)
        }
    }
}
