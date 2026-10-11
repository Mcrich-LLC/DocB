// Assets: the images a page shows, fetched the first time a page needs them and kept, so a
// page read once has its images offline too. Keyed by their resolved URL, which pages of
// every source at a base share.
// ponytail: fetched on first view only; the sync drain can fill this table for offline sources.

import Foundation
import GRDB
import DocBSources

extension Library {
    /// The bytes of an asset a page at `base` refers to, from the store or the host.
    public func asset(_ reference: String, base: URL) async throws -> Data {
        guard let source = try await writer.read({ db in try Library.anySource(base: base.absoluteString, db) }) else {
            throw StoreError.unknownBase(base)
        }
        let url = source.assetURL(for: reference)
        if let stored = try await writer.read({ db in try Data.fetchOne(db, sql: "SELECT body FROM asset WHERE url = ?", arguments: [url.absoluteString]) }) {
            return stored
        }
        let (data, response) = try await transport.fetch(URLRequest(url: url))
        guard (200..<300).contains(response.statusCode) else { throw StoreError.assetNotFound(url, status: response.statusCode) }
        let now = configuration.now()
        try await writer.write { db in
            try db.execute(sql: "INSERT OR REPLACE INTO asset (url, body, fetchedAt) VALUES (?, ?, ?)", arguments: [url.absoluteString, data, now])
        }
        return data
    }
}
