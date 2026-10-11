// Search over navigator titles: FTS5 trigram candidates, then a small in-memory rescoring so
// exact and prefix matches outrank substring hits. Group markers are never results.

import Foundation
import GRDB
import DocBSources

extension Library {
    /// Navigator entries whose title contains `query`, best first.
    public func search(_ query: String, language: String? = nil, limit: Int = 50) async throws -> [SearchHit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let candidateLimit = max(limit * 10, 200)
        let rows: [Row] = try await writer.read { db in
            var sql: String
            var arguments: StatementArguments
            if trimmed.count >= 3 {
                // Trigram matching needs at least three characters; quote the query so FTS syntax never applies.
                let quoted = "\"" + trimmed.replacingOccurrences(of: "\"", with: "\"\"") + "\""
                sql = """
                    SELECT n.*, s.base AS sourceBase, s.kind AS sourceKind, s.title AS sourceTitle, s.languages AS sourceLanguages, s.tags AS sourceTags
                    FROM navigator_fts f JOIN navigator n ON n.id = f.rowid JOIN source s ON s.id = n.sourceID
                    WHERE navigator_fts MATCH ? AND n.path IS NOT NULL AND n.type != 'groupMarker'
                    """
                arguments = [quoted]
            } else {
                sql = """
                    SELECT n.*, s.base AS sourceBase, s.kind AS sourceKind, s.title AS sourceTitle, s.languages AS sourceLanguages, s.tags AS sourceTags
                    FROM navigator n JOIN source s ON s.id = n.sourceID
                    WHERE n.title LIKE ? ESCAPE '\\' AND n.path IS NOT NULL AND n.type != 'groupMarker'
                    """
                let escaped = trimmed.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "%", with: "\\%").replacingOccurrences(of: "_", with: "\\_")
                arguments = ["%\(escaped)%"]
            }
            if let language {
                sql += " AND n.language = ?"
                arguments += [language]
            }
            sql += " LIMIT ?"
            arguments += [candidateLimit]
            return try Row.fetchAll(db, sql: sql, arguments: arguments)
        }

        let needle = trimmed.lowercased()
        var seen: Set<String> = []
        var scored: [(score: Int, hit: SearchHit)] = []
        for row in rows {
            let title: String = row["title"]
            let path: String = row["path"]
            let language: String = row["language"]
            let type: String = row["type"]
            let key = "\(row["sourceBase"] as String)|\(path)|\(language)"
            guard seen.insert(key).inserted else { continue }
            let lower = title.lowercased()
            var score = 0
            if lower == needle { score += 1000 }
            else if lower.hasPrefix(needle) { score += 500 }
            else if lower.split(separator: " ").contains(where: { $0.hasPrefix(needle) }) { score += 250 }
            score -= min(title.count, 100)
            guard let base = URL(string: row["sourceBase"]) else { continue }
            let source = Source(
                base: base,
                kind: try JSONDecoder().decode(Source.Kind.self, from: Data((row["sourceKind"] as String).utf8)),
                title: row["sourceTitle"],
                languages: try JSONDecoder().decode([String].self, from: Data((row["sourceLanguages"] as String).utf8)),
                tags: try JSONDecoder().decode([String].self, from: Data((row["sourceTags"] as String).utf8))
            )
            scored.append((score, SearchHit(source: source, location: PageLocation(base: base, path: path), title: title, type: type, language: language)))
        }
        return scored.sorted { $0.score > $1.score }.prefix(limit).map(\.hit)
    }
}
