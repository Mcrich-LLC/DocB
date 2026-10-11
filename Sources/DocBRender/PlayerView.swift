// The system player on the Mac, with the scroll wheel left to the page: AVPlayerView
// scrubs on it, and a reader scrolling past a video means to scroll.

#if canImport(AppKit)
import AVKit
import SwiftUI

struct PlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> ScrollingPlayerView {
        let view = ScrollingPlayerView()
        view.player = player
        view.controlsStyle = .inline
        return view
    }

    func updateNSView(_ view: ScrollingPlayerView, context: Context) {
        view.player = player
    }
}

/// The player's controls take the scroll wheel in their own subviews, before the player
/// view sees it, so the events are caught at the window and given to the scroll view.
final class ScrollingPlayerView: AVPlayerView {
    // Removed when the view leaves the window, which it does before it goes.
    private var monitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = window == nil ? nil : NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, event.window === window, let scrollView = enclosingScrollView,
                  let hit = window?.contentView?.hitTest(event.locationInWindow), hit.isDescendant(of: self) else { return event }
            scrollView.scrollWheel(with: event)
            return nil
        }
    }
}
#endif
