// The library management screen. Plain SwiftUI so it can be presented in a macOS window today
// and pushed on iOS later. Rows open a detail: a sheet from a hover-revealed Edit button on
// macOS, a pushed destination on iOS.

import ComposableArchitecture
import DocBSources
import DocBStore
import SwiftUI

struct LibraryView: View {
    @Bindable var store: StoreOf<LibraryFeature>

    var body: some View {
        Group {
            if store.sources.isEmpty {
                ContentUnavailableView("No sources", systemImage: "books.vertical", description: Text("Add a documentation site with the + button, or paste its address."))
            } else {
                // A List keeps its scroll position through resizes; a lazy stack re-estimates and jumps.
                List(store.sources, id: \.source) { record in
                    SourceRow(record: record, progress: store.progress[record.source]) {
                        store.send(.editTapped(record.source))
                    }
                }
            }
        }
        .navigationTitle("Library")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if store.isDiscovering {
                    ProgressView().controlSize(.small)
                }
                PasteButton(payloadType: String.self) { strings in
                    if let first = strings.first { store.send(.pasted(first)) }
                }
                .labelStyle(.iconOnly)
                .disabled(store.isDiscovering)
                Button("Add Source", systemImage: "plus") { store.send(.plusTapped) }
                    .disabled(store.isDiscovering)
                Button("Sync All", systemImage: "arrow.clockwise") { store.send(.syncTapped(nil)) }
                    .disabled(store.sources.isEmpty || !store.syncing.isEmpty)
            }
        }
        #if os(macOS)
        .sheet(item: $store.scope(state: \.detail, action: \.detail)) { detail in
            SourceDetailView(store: detail)
        }
        #else
        .navigationDestination(item: $store.scope(state: \.detail, action: \.detail)) { detail in
            SourceDetailView(store: detail)
        }
        .alert("Add Source", isPresented: $store.isAddPromptPresented) {
            TextField("https://", text: $store.addPromptText)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .autocorrectionDisabled()
            Button("Cancel", role: .cancel) {}
            Button("Add") { store.send(.addPromptSubmitted) }
        } message: {
            Text("A DocC site, a page on it, or a developer.apple.com technology.")
        }
        #endif
        .sheet(item: $store.scope(state: \.addURL, action: \.addURL)) { addURL in
            AddURLView(store: addURL)
        }
        .sheet(item: $store.scope(state: \.picker, action: \.picker)) { picker in
            SourcePickerView(store: picker)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
        .task { store.send(.task) }
    }
}

/// One source. Equatable on its values so SwiftUI skips rows whose inputs did not change.
private struct SourceRow: View, @MainActor Equatable {
    let record: SourceRecord
    let progress: String?
    let edit: () -> Void
    @State private var isHovered = false

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.record == rhs.record && lhs.progress == rhs.progress
    }

    var body: some View {
        #if os(macOS)
        HStack {
            labels
            Spacer(minLength: 8)
            Button("Edit", action: edit)
                .opacity(isHovered ? 1 : 0)
        }
        .frame(height: 40)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        #else
        Button(action: edit) {
            HStack {
                labels
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .frame(height: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        #endif
    }

    private var labels: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(record.source.title).lineLimit(1)
            Text(progress ?? synced).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
    }

    private var synced: String {
        guard let date = record.indexSyncedAt else { return "Never synced" }
        return "Synced \(date.formatted(.relative(presentation: .named)))"
    }
}
