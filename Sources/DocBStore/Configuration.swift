// Tunables for a library: how long stored data stays fresh, how retries back off, and the
// clock, which tests replace to move time.

import Foundation

/// Settings for a ``Library``.
public struct Configuration: Sendable {
    /// Age after which a stored navigator or page is revalidated on the next read or sync.
    public var staleAfter: TimeInterval = 24 * 60 * 60

    /// How many pages are fetched concurrently while draining.
    public var concurrency: Int = 4

    /// Pages claimed by one drain batch. Claims expire after `claimDuration` so a dead process frees them.
    public var batchSize: Int = 8
    public var claimDuration: TimeInterval = 120

    /// After this many consecutive failures a page is left alone for `staleAfter` before the next attempt.
    public var maxAttempts: Int = 5

    /// The clock. Tests replace it to age stored data.
    public var now: @Sendable () -> Date = { Date() }

    public init() {}
}
