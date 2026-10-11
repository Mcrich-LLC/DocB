// The `page` table row: one stored or pending page, keyed by base and path and shared by
// every source at that base. The status column is the sync queue.

import Foundation
import GRDB

struct PageRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "page"

    enum Status: String, Codable {
        case pending, fetched, missing
    }

    var base: String
    var path: String
    var status: Status
    var body: Data?
    var etag: String?
    var fetchedAt: Date?
    var revalidate: Bool
    var attempts: Int
    var nextAttemptAt: Date?
    var claimedUntil: Date?
    var lastError: String?

    static func pending(base: String, path: String) -> PageRow {
        PageRow(base: base, path: path, status: .pending, body: nil, etag: nil, fetchedAt: nil, revalidate: false, attempts: 0, nextAttemptAt: nil, claimedUntil: nil, lastError: nil)
    }
}
