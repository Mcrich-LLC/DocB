// A source as the library reports it: the Source plus its sync state and page counts.

import Foundation
import DocBSources

public struct SourceRecord: Equatable, Sendable {
    public var source: Source
    public var offline: Bool
    public var indexSyncedAt: Date?
    public var addedAt: Date
    /// Pages in this source's navigator that are stored.
    public var fetchedPages: Int
    /// Pages in this source's navigator that are pending or flagged for revalidation.
    public var pendingPages: Int
    /// Compressed bytes the stored pages in this source's navigator occupy.
    public var storedBytes: Int

    public init(source: Source, offline: Bool, indexSyncedAt: Date?, addedAt: Date, fetchedPages: Int, pendingPages: Int, storedBytes: Int = 0) {
        self.source = source
        self.offline = offline
        self.indexSyncedAt = indexSyncedAt
        self.addedAt = addedAt
        self.fetchedPages = fetchedPages
        self.pendingPages = pendingPages
        self.storedBytes = storedBytes
    }
}
