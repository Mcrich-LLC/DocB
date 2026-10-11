// The on-disk schema, as GRDB migrations. Sources are keyed by base and kind; navigator rows
// are the flattened index tree per source and language; pages are keyed by base and path and
// shared by every source at that base. The FTS table indexes navigator titles with trigrams.

import GRDB

enum Schema {
    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: "source") { t in
                t.primaryKey("id", .text)
                t.column("base", .text).notNull().indexed()
                t.column("kind", .text).notNull()          // Source.Kind as JSON
                t.column("title", .text).notNull()
                t.column("languages", .text).notNull()     // JSON array
                t.column("tags", .text).notNull()          // JSON array
                t.column("offline", .boolean).notNull().defaults(to: false)
                t.column("indexETag", .text)
                t.column("indexSyncedAt", .datetime)
                t.column("addedAt", .datetime).notNull()
            }
            try db.create(table: "navigator") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("sourceID", .text).notNull().references("source", onDelete: .cascade)
                t.column("language", .text).notNull()
                t.column("parentID", .integer).references("navigator", onDelete: .cascade)
                t.column("position", .integer).notNull()
                t.column("title", .text).notNull()
                t.column("path", .text)                    // normalized PageLocation.path; nil for group markers and external links
                t.column("type", .text).notNull()
                t.column("deprecated", .boolean).notNull().defaults(to: false)
                t.column("beta", .boolean).notNull().defaults(to: false)
                t.column("external", .boolean).notNull().defaults(to: false)
                t.column("icon", .text)
            }
            try db.create(indexOn: "navigator", columns: ["sourceID", "language", "parentID", "position"])
            try db.create(indexOn: "navigator", columns: ["sourceID", "path"])
            try db.create(virtualTable: "navigator_fts", using: FTS5()) { t in
                t.tokenizer = FTS5TokenizerDescriptor(components: ["trigram"])
                t.synchronize(withTable: "navigator")
                t.column("title")
            }
            try db.create(table: "page") { t in
                t.column("base", .text).notNull()
                t.column("path", .text).notNull()
                t.column("status", .text).notNull()        // pending | fetched | missing
                t.column("body", .blob)                    // lzfse-compressed render JSON
                t.column("etag", .text)
                t.column("fetchedAt", .datetime)
                t.column("revalidate", .boolean).notNull().defaults(to: false)
                t.column("attempts", .integer).notNull().defaults(to: 0)
                t.column("nextAttemptAt", .datetime)
                t.column("claimedUntil", .datetime)
                t.column("lastError", .text)
                t.primaryKey(["base", "path"])
            }
            try db.create(indexOn: "page", columns: ["status", "revalidate"])
        }
        // Cascading deletes look children up by parentID; without this index each deleted
        // navigator row scans the whole table, which turns removing a big source into minutes.
        migrator.registerMigration("v2") { db in
            try db.create(indexOn: "navigator", columns: ["parentID"])
        }
        // `sources(containing:)` looks up a path across every source; the (sourceID, path) index
        // cannot serve that.
        migrator.registerMigration("v3") { db in
            try db.create(indexOn: "navigator", columns: ["path"])
        }
        // Trees built before external entries kept their paths have those entries dead; forget
        // every navigator's sync so the next sync fetches and rebuilds it.
        migrator.registerMigration("v4") { db in
            try db.execute(sql: "UPDATE source SET indexSyncedAt = NULL, indexETag = NULL")
        }
        // Images and other assets pages refer to, by their resolved URL.
        migrator.registerMigration("v5") { db in
            try db.create(table: "asset") { t in
                t.primaryKey("url", .text)
                t.column("body", .blob).notNull()
                t.column("fetchedAt", .datetime).notNull()
            }
        }
        return migrator
    }
}
