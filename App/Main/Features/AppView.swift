// A window's content: the reader for that window. A window carries its reader's id and where
// the reader is, kept current as it navigates, so a relaunch brings every window back on its
// page; the one from launch carries nothing at first and is the main reader. On macOS the
// library has a window of its own; elsewhere it is a sheet over the reader.

import ComposableArchitecture
import SwiftUI

struct AppView: View {
    let store: StoreOf<AppFeature>
    @Binding var window: ReaderWindow?
    @State private var showsLibrary = false

    private var readerID: UUID { window?.id ?? ReaderFeature.mainID }

    var body: some View {
        Group {
            if let reader = store.scope(state: \.readers[id: readerID], action: \.readers[id: readerID]) {
                #if os(macOS)
                ReaderView(store: reader)
                #else
                ReaderView(store: reader, openLibrary: { showsLibrary = true })
                    .sheet(isPresented: $showsLibrary) {
                        NavigationStack {
                            LibraryView(store: store.scope(state: \.library, action: \.library))
                                .toolbar {
                                    ToolbarItem(placement: .cancellationAction) {
                                        Button("Done") { showsLibrary = false }
                                    }
                                }
                        }
                    }
                #endif
            } else {
                Color.clear
            }
        }
        .onAppear {
            // Restored at launch: the reader is gone with the last run and is made again.
            if let window, store.readers[id: window.id] == nil { store.send(.windowRestored(window)) }
        }
        .onChange(of: store.readers[id: readerID]?.current, initial: true) { _, route in
            guard let route else { return }
            let current = ReaderWindow(id: readerID, location: route.location)
            if window != current { window = current }
        }
        .onDisappear { store.send(.readerClosed(readerID)) }
    }
}
