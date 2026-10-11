// The app entry point: one root store, a main window with a Go menu, and on macOS a Library
// window on Cmd+L.

import ComposableArchitecture
import SwiftUI

@main
struct DocBApp: App {
    static let store = Store(initialState: AppFeature.State()) {
        AppFeature()
    }

    var body: some Scene {
        WindowGroup(for: ReaderWindow.self) { $window in
            AppView(store: Self.store, window: $window)
        }
        #if !os(iOS)
        // The window's minimum is the columns': sidebar and page with the sidebar showing, the page alone without.
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1280, height: 800)
        #endif
        .commands {
            CommandMenu("Go") { GoMenu() }
        }
        #if os(macOS)
        Window("Library", id: "library") {
            LibraryView(store: Self.store.scope(state: \.library, action: \.library))
                .frame(minWidth: 560, minHeight: 360)
        }
        .keyboardShortcut("l")
        .commands {
            CommandGroup(after: .toolbar) {
                LibraryWindowButton()
            }
        }
        #endif
    }
}

/// Back, forward, and home for the reader in the key window, with the shortcuts the toolbar
/// buttons answer to.
private struct GoMenu: View {
    @FocusedValue(\.reader) private var store

    var body: some View {
        Button("Back") { store?.send(.back) }
            .keyboardShortcut("[", modifiers: .command)
            .disabled(!(store?.canGoBack ?? false))
        Button("Forward") { store?.send(.forward) }
            .keyboardShortcut("]", modifiers: .command)
            .disabled(!(store?.canGoForward ?? false))
        Divider()
        Button("Home") { store?.send(.navigate(.home)) }
            .keyboardShortcut("h", modifiers: [.command, .shift])
            .disabled(store == nil || store?.current == .home)
    }
}

extension FocusedValues {
    /// The reader of the key window.
    @Entry var reader: StoreOf<ReaderFeature>?
}

#if os(macOS)
private struct LibraryWindowButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Library") { openWindow(id: "library") }
            .keyboardShortcut("l")
    }
}
#endif
