// macOS title-bar integration for the reader window: the page's web URL as the represented
// document, so the title shows a proxy icon that drags the link, and a Finder-style path menu
// of the page's parents on Command-click or right-click of the title. SwiftUI owns the window
// delegate, so a forwarding proxy sits in front of it and answers only the path-menu callback.

#if os(macOS)
import AppKit
import DocBRender
import DocBSources
import SwiftUI

struct TitleBarDocument: NSViewRepresentable {
    var webURL: URL?
    /// The page first, then its ancestors up to the landing page.
    var entries: [ReaderFeature.State.PathEntry]
    var open: (PageLocation) -> Void

    func makeNSView(context: Context) -> HostView {
        HostView()
    }

    func updateNSView(_ view: HostView, context: Context) {
        view.apply = { [webURL, entries, open] window in
            let delegate = PathMenuDelegate.install(on: window)
            view.delegate = delegate   // the window only holds its delegate weakly
            delegate.entries = entries
            delegate.open = open
            window.representedURL = webURL
            if let page = entries.first {
                window.standardWindowButton(.documentIconButton)?.image = TopicIconView.nsImage(for: page.kind)
            }
        }
        if let window = view.window { view.apply?(window) }
    }

    final class HostView: NSView {
        var apply: ((NSWindow) -> Void)?
        var delegate: PathMenuDelegate?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window { apply?(window) }
        }
    }
}

/// Stands in front of SwiftUI's window delegate; everything but the path menu is forwarded.
@MainActor
final class PathMenuDelegate: NSObject, NSWindowDelegate {
    /// SwiftUI's own delegate, kept strongly since the window does not.
    private var original: (any NSWindowDelegate)?
    var entries: [ReaderFeature.State.PathEntry] = []
    var open: ((PageLocation) -> Void)?

    static func install(on window: NSWindow) -> PathMenuDelegate {
        if let installed = window.delegate as? PathMenuDelegate { return installed }
        let proxy = PathMenuDelegate()
        proxy.original = window.delegate
        window.delegate = proxy
        return proxy
    }

    override func responds(to selector: Selector!) -> Bool {
        super.responds(to: selector) || (original?.responds(to: selector) ?? false)
    }

    override func forwardingTarget(for selector: Selector!) -> Any? {
        original
    }

    func window(_ window: NSWindow, shouldPopUpDocumentPathMenu menu: NSMenu) -> Bool {
        menu.removeAllItems()
        for (index, entry) in entries.enumerated() {
            let item = NSMenuItem(title: entry.title, action: #selector(pick(_:)), keyEquivalent: "")
            item.image = TopicIconView.nsImage(for: entry.kind)
            item.target = self
            item.tag = index
            item.isEnabled = entry.location != nil
            menu.addItem(item)
        }
        return !entries.isEmpty
    }

    @objc private func pick(_ item: NSMenuItem) {
        if let location = entries[item.tag].location { open?(location) }
    }
}
#endif
