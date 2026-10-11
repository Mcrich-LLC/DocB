// The failure discovery reports when no probe hits, carrying every URL it checked so the
// user can see what was tried.

import Foundation

/// No documentation was found at any candidate base URL.
public struct DiscoveryError: Error, Equatable {
    /// Every URL that was probed, in order.
    public var tried: [URL]

    public init(tried: [URL]) {
        self.tried = tried
    }
}
