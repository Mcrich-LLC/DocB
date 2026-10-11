// The offline library: one SQLite file holding sources, their navigators, and pages. A CLI
// and an app open the same file; SQLite's write serialization and per-row page claims are the
// only coordination. This file holds opening and source management; sync, pages, and search
// are in their own extensions.

import Foundation
import GRDB
import DocBSources

public actor Library {
    let writer: any DatabaseWriter
    let transport: Transport
    let configuration: Configuration
    var eventHandler: (@Sendable (SyncEvent) -> Void)?

    /// Opens or creates the library file, migrating as needed.
    public init(path: URL, transport: Transport = .urlSession(), configuration: Configuration = Configuration()) throws {
        var config = GRDB.Configuration()
        config.busyMode = .timeout(10)
        let pool = try DatabasePool(path: path.path(percentEncoded: false), configuration: config)
        try Schema.migrator.migrate(pool)
        writer = pool
        self.transport = transport
        self.configuration = configuration
    }

    /// Where the library lives when nobody says otherwise: `$DOCB_LIBRARY`, else Application Support.
    ///
    /// The directory is created if needed.
    public static func defaultLocation() throws -> URL {
        let path: URL
        if let env = ProcessInfo.processInfo.environment["DOCB_LIBRARY"] {
            path = URL(fileURLWithPath: env)
        } else {
            let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            path = support.appending(path: "DocB/library.sqlite")
        }
        try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        return path
    }

    /// An in-memory library for tests and throwaway use.
    public init(inMemory transport: Transport, configuration: Configuration = Configuration()) throws {
        let queue = try DatabaseQueue()
        try Schema.migrator.migrate(queue)
        writer = queue
        self.transport = transport
        self.configuration = configuration
    }

    /// Receives events from background revalidation triggered by reads. `sync` streams its own events.
    public func setEventHandler(_ handler: (@Sendable (SyncEvent) -> Void)?) {
        eventHandler = handler
    }

    // MARK: Sources

    /// Adds a source. Nothing is fetched until `sync`. Throws `StoreError.duplicateSource` if it is already there.
    public func add(_ source: Source, offline: Bool = false) async throws {
        let row = try SourceRow(source: source, offline: offline, addedAt: configuration.now())
        try await writer.write { db in
            guard try SourceRow.exists(db, key: row.id) == false else {
                throw StoreError.duplicateSource(source)
            }
            try row.insert(db)
        }
    }

    /// Removes a source, its navigator, and every page only it reached.
    public func remove(_ source: Source) async throws {
        let id = source.storeID
        let base = source.base.absoluteString
        try await writer.write { db in
            let paths = try Set(String.fetchAll(db, sql: "SELECT path FROM navigator WHERE sourceID = ? AND path IS NOT NULL", arguments: [id]))
            try db.execute(sql: "DELETE FROM source WHERE id = ?", arguments: [id])
            try Library.purge(db, base: base, paths: paths)
        }
    }

    /// Turns full offline download on or off. Turning it on enqueues every navigator page.
    public func setOffline(_ source: Source, _ offline: Bool) async throws {
        let id = source.storeID
        let base = source.base.absoluteString
        try await writer.write { db in
            try db.execute(sql: "UPDATE source SET offline = ? WHERE id = ?", arguments: [offline, id])
            if offline {
                try Library.enqueue(db, base: base, paths: Set(String.fetchAll(db, sql: "SELECT path FROM navigator WHERE sourceID = ? AND path IS NOT NULL", arguments: [id])))
            }
        }
    }

    public func sources() async throws -> [SourceRecord] {
        try await writer.read { db in
            try SourceRow.order(sql: "title COLLATE NOCASE, id").fetchAll(db).map { row in
                let counts = try Row.fetchOne(db, sql: """
                    SELECT
                      SUM(CASE WHEN page.status = 'fetched' THEN 1 ELSE 0 END) AS fetched,
                      SUM(CASE WHEN page.status = 'pending' OR page.revalidate THEN 1 ELSE 0 END) AS pending,
                      SUM(COALESCE(LENGTH(page.body), 0)) AS bytes
                    FROM (SELECT DISTINCT path FROM navigator WHERE sourceID = ? AND path IS NOT NULL) AS n
                    JOIN page ON page.base = ? AND page.path = n.path
                    """, arguments: [row.id, row.base])
                return SourceRecord(
                    source: try row.source,
                    offline: row.offline,
                    indexSyncedAt: row.indexSyncedAt,
                    addedAt: row.addedAt,
                    fetchedPages: counts?["fetched"] ?? 0,
                    pendingPages: counts?["pending"] ?? 0,
                    storedBytes: counts?["bytes"] ?? 0
                )
            }
        }
    }

    /// Sources whose navigator lists `path` as one of its own pages, in the order they were
    /// added. External nodes that merely link to the page do not count.
    public func sources(containing path: String) async throws -> [Source] {
        try await writer.read { db in
            try SourceRow
                .filter(sql: "id IN (SELECT DISTINCT sourceID FROM navigator WHERE path = ? AND NOT external)", arguments: [path])
                .order(Column("addedAt"))
                .fetchAll(db)
                .map { try $0.source }
        }
    }

    // MARK: Shared page bookkeeping

    /// Deletes pages at `base` from `paths` that no remaining navigator at that base references.
    static func purge(_ db: Database, base: String, paths: Set<String>) throws {
        guard !paths.isEmpty else { return }
        let referenced = try Set(String.fetchAll(db, sql: "SELECT DISTINCT n.path FROM navigator n JOIN source s ON s.id = n.sourceID WHERE s.base = ? AND n.path IS NOT NULL", arguments: [base]))
        for path in paths.subtracting(referenced) {
            try db.execute(sql: "DELETE FROM page WHERE base = ? AND path = ?", arguments: [base, path])
        }
    }

    /// Inserts pending rows for paths that have none, and gives previously missing ones another chance.
    static func enqueue(_ db: Database, base: String, paths: Set<String>) throws {
        for path in paths {
            try db.execute(sql: "INSERT OR IGNORE INTO page (base, path, status, revalidate, attempts) VALUES (?, ?, 'pending', 0, 0)", arguments: [base, path])
            try db.execute(sql: "UPDATE page SET status = 'pending', attempts = 0, nextAttemptAt = NULL WHERE base = ? AND path = ? AND status = 'missing'", arguments: [base, path])
        }
    }

    /// Any source at a base, which is all that is needed to build that base's URLs.
    static func anySource(base: String, _ db: Database) throws -> Source? {
        try SourceRow.filter(Column("base") == base).fetchOne(db)?.source
    }

    /// A source at a base, whichever if several share it: its kind says where assets live.
    public func source(base: URL) async throws -> Source? {
        try await writer.read { db in try Library.anySource(base: base.absoluteString, db) }
    }

    func emit(_ event: SyncEvent) {
        eventHandler?(event)
    }
}
