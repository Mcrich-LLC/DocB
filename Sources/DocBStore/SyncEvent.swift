// Progress reported while syncing: navigator outcomes per source, and page outcomes per page.

import DocBSources

public enum SyncEvent: Equatable, Sendable {
    case navigatorUpdated(Source)
    case navigatorUnchanged(Source)
    case navigatorFailed(Source, String)
    case pageFetched(PageLocation)
    /// A stored page was revalidated and its body changed.
    case pageUpdated(PageLocation)
    case pageUnchanged(PageLocation)
    case pageMissing(PageLocation)
    case pageFailed(PageLocation, String)
    /// Pages still pending or flagged after a drain pass.
    case remaining(Int)
    case finished
}
