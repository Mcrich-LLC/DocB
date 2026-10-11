// The `source` table row: a Source flattened into columns plus its sync state.

import Foundation
import GRDB
import DocBSources

struct SourceRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "source"

    var id: String
    var base: String
    var kind: String
    var title: String
    var languages: String
    var tags: String
    var offline: Bool
    var indexETag: String?
    var indexSyncedAt: Date?
    var addedAt: Date

    init(source: Source, offline: Bool, addedAt: Date) throws {
        id = source.storeID
        base = source.base.absoluteString
        kind = try String(decoding: JSONEncoder().encode(source.kind), as: UTF8.self)
        title = source.title
        languages = try String(decoding: JSONEncoder().encode(source.languages), as: UTF8.self)
        tags = try String(decoding: JSONEncoder().encode(source.tags), as: UTF8.self)
        self.offline = offline
        self.addedAt = addedAt
    }

    var source: Source {
        get throws {
            guard let url = URL(string: base) else { throw StoreError.corruptRow("source \(id)") }
            return Source(
                base: url,
                kind: try JSONDecoder().decode(Source.Kind.self, from: Data(kind.utf8)),
                title: title,
                languages: try JSONDecoder().decode([String].self, from: Data(languages.utf8)),
                tags: try JSONDecoder().decode([String].self, from: Data(tags.utf8))
            )
        }
    }
}

extension Source {
    /// The stable key a source is stored under: base plus kind.
    var storeID: String {
        switch kind {
        case .docc: "\(base.absoluteString)|docc"
        case .doccWithoutIndex(let root): "\(base.absoluteString)|crawl:\(root)"
        case .appleDeveloper(let module): "\(base.absoluteString)|apple:\(module)"
        }
    }
}
