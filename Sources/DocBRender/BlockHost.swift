#if canImport(AppKit)
import AppKit
import SwiftUI

/// One view hosting every block's view on the page. AppKit tells each subview of a scrolling
/// document that its place in the window changed, on every frame, and a hosting view answers
/// with a layout, a render, and its pointer regions; the window then walks them all again for
/// its tracking areas and drag regions. One host is told once.
@MainActor final class BlockHost: NSHostingView<BlockLayer> {
    let placements = BlockPlacements()

    init() {
        super.init(rootView: BlockLayer(placements: placements))
        autoresizingMask = []
        // Sized from outside, by the frame; neither an intrinsic size nor a safe area to work
        // out again on every scroll frame.
        sizingOptions = []
        safeAreaRegions = []
    }

    @available(*, unavailable) required init(rootView: BlockLayer) { fatalError() }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    /// The stretches between blocks are the text's: a hit there goes through.
    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        guard hit === self, let superview else { return hit }
        let local = convert(point, from: superview)
        return placements.items.contains { $0.frame.contains(local) } ? self : nil
    }

    /// The frame of the block a point is in, if any.
    func item(at point: NSPoint) -> BlockPlacements.Item? {
        placements.items.first { $0.frame.contains(point) }
    }
}
#endif
