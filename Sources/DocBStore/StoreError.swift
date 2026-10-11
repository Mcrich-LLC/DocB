// Failures the library reports to callers.

import Foundation
import DocBSources

public enum StoreError: Error, Equatable {
    /// The page is not stored and could not be fetched.
    case pageUnavailable(PageLocation)
    /// The host answered with a non-success status for a page that is not stored.
    case pageNotFound(PageLocation, status: Int)
    /// The host answered with a non-success status for an asset that is not stored.
    case assetNotFound(URL, status: Int)
    /// The navigator could not be fetched.
    case navigatorUnavailable(Source, status: Int)
    /// A location's base has no source in the library, so its kind is unknown.
    case unknownBase(URL)
    /// The source is already in the library.
    case duplicateSource(Source)
    /// A stored row could not be read back.
    case corruptRow(String)
}
