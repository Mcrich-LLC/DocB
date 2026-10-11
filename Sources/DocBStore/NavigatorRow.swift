// The `navigator` table row: one node of a source's flattened index tree in one language.

import GRDB

struct NavigatorRow: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "navigator"

    var id: Int64?
    var sourceID: String
    var language: String
    var parentID: Int64?
    var position: Int
    var title: String
    var path: String?
    var type: String
    var deprecated: Bool
    var beta: Bool
    var external: Bool
    var icon: String?

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
