import SwiftUI

/// Every block's view and where it sits on the page, for the one view that hosts them all.
@MainActor @Observable final class BlockPlacements {
    struct Item: Identifiable {
        let id: ObjectIdentifier
        let view: AnyView
        let frame: CGRect
    }

    var items: [Item] = []
    var size: CGSize = .zero
}
