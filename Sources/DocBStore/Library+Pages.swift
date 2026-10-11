// Pages: reading with cache-as-you-go and stale-while-revalidate, and the drain that fetches
// pending and flagged rows with bounded concurrency. Rows are claimed with an expiry so two
// processes never fetch the same page at once and a dead process frees its claims.

import Foundation
import GRDB
import DocCSchema
import DocBSources

extension Library {
    /// The stored page, fetching and storing it first if needed. A stale stored page is returned
    /// at once and revalidated in the background.
    public func page(at location: PageLocation) async throws -> sending RenderNode {
        try RenderJSONDecoder.makeDecoder().decode(RenderNode.self, from: try await pageData(at: location))
    }

    /// The stored page in a language it has a variant for, with that variant's overrides
    /// applied; in the language it was authored in otherwise.
    public func page(at location: PageLocation, language: String) async throws -> sending RenderNode {
        let data = try await pageData(at: location)
        let node = try RenderJSONDecoder.makeDecoder().decode(RenderNode.self, from: data)
        guard language != node.identifier.sourceLanguage.id, node.availableLanguages.contains(language) else { return node }
        let overridden = try RenderNodeVariantOverridesApplier().applyVariantOverrides(in: data, for: [.interfaceLanguage(language)])
        return try RenderJSONDecoder.makeDecoder().decode(RenderNode.self, from: overridden)
    }

    /// The page's render JSON as served, with the same caching and revalidation as `page(at:)`.
    /// Use it to apply language variant overrides before decoding.
    public func pageData(at location: PageLocation) async throws -> Data {
        let base = location.base.absoluteString
        let stored = try await writer.read { db in
            try PageRow.filter(Column("base") == base && Column("path") == location.path).fetchOne(db)
        }
        if let stored, let body = stored.body {
            let data = try Compression.decompress(body)
            if isStale(stored) {
                try await writer.write { db in
                    try db.execute(sql: "UPDATE page SET revalidate = 1 WHERE base = ? AND path = ?", arguments: [base, location.path])
                }
                Task { [self] in
                    try? await drain(deadline: nil) { event in Task { await self.emit(event) } }
                }
            }
            return data
        }
        guard let source = try await writer.read({ db in try Library.anySource(base: base, db) }) else {
            throw StoreError.unknownBase(location.base)
        }
        switch try await fetch(location, source: source, etag: nil) {
        case .updated(let data, let etag):
            try await store(location, data: data, etag: etag, previous: stored)
            return data
        case .missing(let status):
            throw StoreError.pageNotFound(location, status: status)
        case .unchanged:
            throw StoreError.pageUnavailable(location)
        }
    }

    func isStale(_ row: PageRow) -> Bool {
        guard let fetchedAt = row.fetchedAt else { return true }
        return configuration.now().timeIntervalSince(fetchedAt) >= configuration.staleAfter
    }

    /// Flags fetched pages of offline sources that are older than `staleAfter`.
    func flagStalePages() async throws {
        let cutoff = configuration.now().addingTimeInterval(-configuration.staleAfter)
        try await writer.write { db in
            try db.execute(sql: """
                UPDATE page SET revalidate = 1
                WHERE status = 'fetched' AND revalidate = 0 AND fetchedAt < ?
                  AND EXISTS (
                    SELECT 1 FROM navigator n JOIN source s ON s.id = n.sourceID
                    WHERE s.offline AND s.base = page.base AND n.path = page.path
                  )
                """, arguments: [cutoff])
        }
    }

    enum FetchOutcome {
        case updated(Data, etag: String?)
        case unchanged
        case missing(status: Int)
    }

    /// One conditional GET of a page's data file.
    func fetch(_ location: PageLocation, source: Source, etag: String?) async throws -> FetchOutcome {
        var request = URLRequest(url: source.dataURL(for: location))
        if let etag {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        let (data, response) = try await transport.fetch(request)
        switch response.statusCode {
        case 304: return .unchanged
        case 200..<300: return .updated(data, etag: response.value(forHTTPHeaderField: "ETag"))
        default: return .missing(status: response.statusCode)
        }
    }

    func store(_ location: PageLocation, data: Data, etag: String?, previous: PageRow?) async throws {
        let body = try Compression.compress(data)
        let now = configuration.now()
        var updated = previous ?? .pending(base: location.base.absoluteString, path: location.path)
        updated.status = .fetched
        updated.body = body
        updated.etag = etag
        updated.fetchedAt = now
        updated.revalidate = false
        updated.attempts = 0
        updated.nextAttemptAt = nil
        updated.claimedUntil = nil
        updated.lastError = nil
        let row = updated
        try await writer.write { db in try row.save(db) }
    }

    // MARK: Drain

    /// Fetches pending and flagged pages until none are left, the deadline passes, or the task is cancelled.
    func drain(deadline: Date?, emit: @escaping @Sendable (SyncEvent) -> Void) async throws {
        var sources: [String: Source] = [:]
        while true {
            try Task.checkCancellation()
            if let deadline, configuration.now() >= deadline { return }
            let batch = try await claim()
            if batch.isEmpty { return }
            for row in batch where sources[row.base] == nil {
                sources[row.base] = try await writer.read { db in try Library.anySource(base: row.base, db) }
            }
            let work = batch.compactMap { row in sources[row.base].map { (row, $0) } }
            let concurrency = configuration.concurrency
            await withTaskGroup(of: Void.self) { group in
                var iterator = work.makeIterator()
                var running = 0
                while running < concurrency, let (row, source) = iterator.next() {
                    running += 1
                    group.addTask { await self.process(row, source: source, emit: emit) }
                }
                while await group.next() != nil {
                    running -= 1
                    if let (row, source) = iterator.next() {
                        running += 1
                        group.addTask { await self.process(row, source: source, emit: emit) }
                    }
                }
            }
        }
    }

    /// Atomically claims a batch of due rows for this process.
    func claim() async throws -> [PageRow] {
        let now = configuration.now()
        let until = now.addingTimeInterval(configuration.claimDuration)
        let limit = configuration.batchSize
        return try await writer.write { db in
            let rows = try PageRow.fetchAll(db, sql: """
                SELECT * FROM page
                WHERE (status = 'pending' OR revalidate)
                  AND (nextAttemptAt IS NULL OR nextAttemptAt <= ?)
                  AND (claimedUntil IS NULL OR claimedUntil < ?)
                ORDER BY base, path
                LIMIT ?
                """, arguments: [now, now, limit])
            for row in rows {
                try db.execute(sql: "UPDATE page SET claimedUntil = ? WHERE base = ? AND path = ?", arguments: [until, row.base, row.path])
            }
            return rows
        }
    }

    func process(_ row: PageRow, source: Source, emit: @escaping @Sendable (SyncEvent) -> Void) async {
        let location = PageLocation(base: source.base, path: row.path)
        let hadBody = row.body != nil
        do {
            switch try await fetch(location, source: source, etag: row.etag) {
            case .updated(let data, let etag):
                try await store(location, data: data, etag: etag, previous: row)
                emit(hadBody ? .pageUpdated(location) : .pageFetched(location))
            case .unchanged:
                try await touch(row)
                emit(.pageUnchanged(location))
            case .missing(let status):
                // A page that is still stored stays readable; the next navigator sync purges it if it is really gone.
                var updated = row
                updated.status = hadBody ? .fetched : .missing
                updated.revalidate = false
                updated.claimedUntil = nil
                updated.lastError = "HTTP \(status)"
                let saved = updated
                try await writer.write { db in try saved.save(db) }
                emit(.pageMissing(location))
            }
        } catch {
            var updated = row
            updated.attempts += 1
            updated.claimedUntil = nil
            updated.lastError = String(describing: error)
            if updated.attempts >= configuration.maxAttempts {
                updated.attempts = 0
                updated.nextAttemptAt = configuration.now().addingTimeInterval(configuration.staleAfter)
            } else {
                updated.nextAttemptAt = configuration.now().addingTimeInterval(pow(2, Double(updated.attempts)) * 5)
            }
            let saved = updated
            try? await writer.write { db in try saved.save(db) }
            emit(.pageFailed(location, saved.lastError ?? ""))
        }
    }

    func touch(_ row: PageRow) async throws {
        var updated = row
        updated.fetchedAt = configuration.now()
        updated.revalidate = false
        updated.claimedUntil = nil
        updated.attempts = 0
        updated.nextAttemptAt = nil
        updated.lastError = nil
        let saved = updated
        try await writer.write { db in try saved.save(db) }
    }
}
