// The add-by-URL sheet: a single field, cancel and add, a spinner while discovering, and the
// picker nested on top when the URL turns out to be a catalog.

import ComposableArchitecture
import SwiftUI

struct AddURLView: View {
    @Bindable var store: StoreOf<AddURLFeature>
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Source").font(.headline)
            Text("Paste the address of a DocC site, a page on it, or a developer.apple.com technology.")
                .font(.callout)
                .foregroundStyle(.secondary)
            TextField("https://", text: $store.urlText)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit { store.send(.submitTapped) }
                .disabled(store.isDiscovering)
                #if !os(macOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                #endif
                .autocorrectionDisabled()
            HStack {
                Button("Cancel") { store.send(.cancelTapped) }.keyboardShortcut(.cancelAction)
                Spacer()
                if store.isDiscovering {
                    ProgressView().controlSize(.small)
                }
                Button("Add") { store.send(.submitTapped) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(store.url == nil || store.isDiscovering)
            }
        }
        .padding(20)
        .frame(minWidth: 460)
        .onAppear { focused = true }
        .sheet(item: $store.scope(state: \.picker, action: \.picker)) { picker in
            SourcePickerView(store: picker)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }
}
