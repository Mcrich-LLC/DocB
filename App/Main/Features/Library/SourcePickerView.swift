// The multi-select picker for a catalog: a filterable checklist with cancel on the left,
// "Add n" on the right, and select all in between. A bottom bar on macOS, a toolbar elsewhere.

import ComposableArchitecture
import DocBSources
import SwiftUI

struct SourcePickerView: View {
    @Bindable var store: StoreOf<SourcePickerFeature>

    var body: some View {
        #if os(macOS)
        VStack(spacing: 0) {
            header
            list
            Divider()
            HStack {
                Button("Cancel") { store.send(.cancelTapped) }.keyboardShortcut(.cancelAction)
                Spacer()
                selectAllButton
                addButton
            }
            .padding()
        }
        .frame(minWidth: 460, minHeight: 520)
        #else
        NavigationStack {
            list
                .navigationTitle("Add Sources")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { store.send(.cancelTapped) } }
                    ToolbarItem(placement: .confirmationAction) { addButton }
                    ToolbarItem(placement: .bottomBar) { selectAllButton }
                }
        }
        #endif
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This site offers \(store.candidates.count) technologies.").font(.headline)
            TextField("Filter", text: $store.filter).textFieldStyle(.roundedBorder)
        }
        .padding()
    }

    private var list: some View {
        List(store.filtered, id: \.self) { source in
            CandidateRow(title: source.title, languages: source.languages.joined(separator: ", "), isSelected: store.selected.contains(source)) {
                store.send(.toggled(source))
            }
        }
        #if !os(macOS)
        .searchable(text: $store.filter, placement: .navigationBarDrawer(displayMode: .always))
        #endif
    }

    private var selectAllButton: some View {
        Button(store.allSelected ? "Unselect All" : "Select All") { store.send(.selectAllTapped) }
    }

    private var addButton: some View {
        Button(store.selected.isEmpty ? "Add" : "Add \(store.selected.count)") { store.send(.addTapped) }
            .keyboardShortcut(.defaultAction)
            .disabled(store.selected.isEmpty)
    }
}

/// One candidate. Equatable on plain values so SwiftUI skips rows whose inputs did not change.
private struct CandidateRow: View, @MainActor Equatable {
    let title: String
    let languages: String
    let isSelected: Bool
    let toggle: () -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.title == rhs.title && lhs.languages == rhs.languages && lhs.isSelected == rhs.isSelected
    }

    var body: some View {
        Button(action: toggle) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                Text(title).lineLimit(1)
                Spacer()
                Text(languages).foregroundStyle(.secondary).font(.caption).lineLimit(1)
            }
            .frame(height: 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
