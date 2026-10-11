// The source detail screen: name, origin, sync time, cached pages and their size, with
// refresh, the offline toggle, and delete.

import ComposableArchitecture
import DocBSources
import DocBStore
import SwiftUI

struct SourceDetailView: View {
    let store: StoreOf<SourceDetailFeature>

    var body: some View {
        #if os(macOS)
        VStack(spacing: 0) {
            form
            Divider()
            HStack {
                Button("Delete", role: .destructive) { store.send(.deleteTapped) }
                Spacer()
                Button("Close") { store.send(.closeTapped) }.keyboardShortcut(.cancelAction)
            }
            .padding()
        }
        .frame(minWidth: 460)
        #else
        form
            .navigationTitle(store.record.source.title)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var form: some View {
        Form {
            Section {
                LabeledContent("Name", value: store.record.source.title)
                LabeledContent("Origin", value: origin)
                LabeledContent("Last sync", value: synced)
            }
            Section {
                LabeledContent("Cached pages", value: pages)
                LabeledContent("Size on disk", value: store.record.storedBytes.formatted(.byteCount(style: .file)))
                if let progress = store.progress {
                    LabeledContent("Progress", value: progress)
                }
            }
            Section {
                Toggle("Download all pages for offline reading", isOn: Binding(get: { store.record.offline }, set: { store.send(.offlineToggled($0)) }))
                HStack {
                    Button("Refresh Now", systemImage: "arrow.clockwise") { store.send(.refreshTapped) }
                        .disabled(store.isSyncing)
                    if store.isSyncing {
                        ProgressView().controlSize(.small)
                    }
                }
            }
            #if !os(macOS)
            Section {
                Button("Delete Source", role: .destructive) { store.send(.deleteTapped) }
            }
            #endif
        }
        .formStyle(.grouped)
    }

    private var origin: String {
        switch store.record.source.kind {
        case .docc: store.record.source.base.absoluteString
        case .doccWithoutIndex: "\(store.record.source.base.absoluteString) (no index, crawled)"
        case .appleDeveloper(let module): "\(store.record.source.base.absoluteString) · \(module)"
        }
    }

    private var synced: String {
        store.record.indexSyncedAt.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "Never"
    }

    private var pages: String {
        var text = "\(store.record.fetchedPages)"
        if store.record.pendingPages > 0 { text += " (\(store.record.pendingPages) pending)" }
        return text
    }
}
