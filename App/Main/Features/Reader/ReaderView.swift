// The reader window: sidebar and page in a split view, with back and forward in the toolbar.
// Back and forward are menus with a primary action: a click steps once, press and hold lists
// the history on that side to jump to. Their shortcuts live in the Go menu, so the jump
// lists do not show them against every entry.
// At home the page pane lists the sources too, so an empty library says what to do.

import ComposableArchitecture
import DocBRender
import DocCSchema
import Foundation
import OSLog
import DocBSources
import DocBStore
import SwiftUI

struct ReaderView: View {
    @Bindable var store: StoreOf<ReaderFeature>
    /// Opens the library, where it is a sheet rather than a window of its own.
    var openLibrary: (() -> Void)? = nil

    #if !os(iOS)
    static let pageMinWidth: CGFloat = 580
    #if os(visionOS)
    static let sidebarMinWidth: CGFloat = 420
    #else
    static let sidebarMinWidth: CGFloat = 220
    #endif
    #endif

    var body: some View {
        NavigationSplitView(columnVisibility: $store.columnVisibility) {
            SidebarView(store: store.scope(state: \.sidebar, action: \.sidebar), route: store.current, sources: store.sources) { source in
                store.send(.sourcePicked(source))
            }
            #if os(visionOS)
            .navigationSplitViewColumnWidth(min: Self.sidebarMinWidth, ideal: 420, max: 420)   // it cannot be dragged there
            #elseif os(macOS)
            .navigationSplitViewColumnWidth(min: Self.sidebarMinWidth, ideal: 280)
            #else
            .navigationSplitViewColumnWidth(min: 220, ideal: 280)
            #endif
        } detail: {
            Group {
                switch store.page {
                case .home:
                    HomePage(sources: store.sources) { store.send(.sourcePicked($0)) }
                default:
                    PagePane(page: store.page, missingModule: store.missingModule) { reference in
                        store.send(.linkTapped(reference))
                    }
                }
            }
            #if !os(iOS)
            // The page never goes under 580; with the sidebar showing, the window will not go under
            // the two together, and opening the sidebar grows the window to that rather than
            // squeezing the page.
            .navigationSplitViewColumnWidth(min: Self.pageMinWidth, ideal: 860)
            #endif
            #if os(visionOS)
            // Without a sidebar column the detail gets a navigation bar of its own, empty since
            // the ornament holds everything, and 92 points tall above the page.
            .toolbar(.hidden, for: .navigationBar)
            #endif
        }
        .toolbar {
            #if !os(visionOS)
            ToolbarItemGroup(placement: .navigation) {
                Button("Home", systemImage: "house") { store.send(.navigate(.home)) }
                    .disabled(store.current == .home)
                    .help("Home")
                back
                forward
            }
            #endif
            #if !os(visionOS)
            if let openLibrary {
                ToolbarItem(placement: .primaryAction) { library }
            }
            ToolbarItem(placement: .primaryAction) { languagePicker }
            #endif
        }
        .navigationTitle(title)
        #if !os(iOS)
        // The split view does not hand its columns' minimums to the window, so the reader states
        // them: sidebar and page with the sidebar showing, the page alone without.
        .frame(minWidth: store.columnVisibility == .detailOnly ? Self.pageMinWidth : Self.pageMinWidth + Self.sidebarMinWidth, minHeight: 400)
        #endif
        #if os(visionOS)
        // Everything lives in a top ornament: the sidebar, home, the history, the language, the library.
        .toolbar(removing: .sidebarToggle)
        .ornament(attachmentAnchor: .scene(.top), contentAlignment: .bottom) {
            HStack(spacing: 12) {
                Button("Sidebar", systemImage: "sidebar.leading") {
                    store.columnVisibility = store.columnVisibility == .detailOnly ? .all : .detailOnly
                }
                Button("Home", systemImage: "house") { store.send(.navigate(.home)) }
                    .disabled(store.current == .home)
                Divider().frame(height: 24)
                back
                forward
                Divider().frame(height: 24)
                languagePicker
                    .labelStyle(.titleOnly)
                    .fixedSize()   // the ornament would otherwise squeeze the name into a column
                if openLibrary != nil { library }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .glassBackgroundEffect()
            .padding(.bottom, 16)   // hovering above the window, with a gap
        }
        #endif
        #if os(macOS)
        .background(TitleBarDocument(webURL: loadedPage?.webURL, entries: store.state.pathEntries) { store.send(.navigate(.page($0))) })
        #endif
        .focusedSceneValue(\.reader, store)
        .alert($store.scope(state: \.alert, action: \.alert))
        .task { store.send(.task) }
    }

    private var title: String {
        loadedPage?.title ?? "DocB"
    }

    private var library: some View {
        Button("Library", systemImage: "books.vertical") { openLibrary?() }
    }

    /// The page's languages; a page with one still shows it, greyed.
    private var languagePicker: some View {
        Picker("Language", selection: Binding(get: { store.shownLanguage }, set: { store.send(.binding(.set(\.language, $0))) })) {
            ForEach(store.languages, id: \.self) { language in
                Text(SourceLanguage(id: language).name).tag(language)
            }
        }
        .pickerStyle(.menu)
        .disabled(store.languages.count < 2)
        .help("Language")
    }

    private var back: some View {
        jumpList("Back", systemImage: "chevron.left", entries: jumps((0..<store.index).reversed()), step: .back)
            .disabled(!store.canGoBack)
    }

    private var forward: some View {
        jumpList("Forward", systemImage: "chevron.right", entries: jumps((store.index + 1)..<store.history.count), step: .forward)
            .disabled(!store.canGoForward)
    }

    private var loadedPage: RenderedPage? {
        if case .loaded(_, let page) = store.page { return page }
        return nil
    }

    /// A history entry for a jump list, captured with its title so a stale menu never indexes history.
    private struct Jump: Identifiable {
        var id: Int
        var heading: ReaderFeature.State.Heading
    }

    private func jumps(_ indices: some Sequence<Int>) -> [Jump] {
        let state = store.state
        return indices.map { Jump(id: $0, heading: state.heading(for: state.history[$0])) }
    }

    private func jumpList(_ title: String, systemImage: String, entries: [Jump], step: ReaderFeature.Action) -> some View {
        Menu {
            ForEach(entries) { jump in
                Button { store.send(.jump(jump.id)) } label: {
                    // Menus show plain text only, so the badge is a word after the title.
                    Label { Text(jump.heading.badge.map { jump.heading.title + " (\($0.title))" } ?? jump.heading.title) } icon: { TopicIconView.image(for: jump.heading.kind) }
                        .labelStyle(.titleAndIcon)   // macOS menus drop the icon by default
                }
            }
        } label: {
            Label(title, systemImage: systemImage)
        } primaryAction: {
            store.send(step)
        }
        .menuIndicator(.hidden)
    }
}

private struct HomePage: View {
    let sources: [SourceRecord]
    let open: (Source) -> Void

    var body: some View {
        // An empty library says so in the sidebar; here it is just an empty grid.
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 16)], spacing: 16) {
                ForEach(sources, id: \.source) { record in
                    Button { open(record.source) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.source.title).font(.headline).lineLimit(1)
                            Text(record.offline ? "\(record.fetchedPages) pages offline" : "\(record.fetchedPages) pages cached")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
        }
    }
}

private struct PagePane: View {
    @Dependency(\.library) private var library
    let page: ReaderFeature.State.Page
    let missingModule: String?
    let openLink: (String) -> Void

    var body: some View {
        Group {
            switch page {
            case .home:
                EmptyView()
            case .loading:
                ProgressView()
            case .failed(let location, let error):
                ContentUnavailableView("Could not load page", systemImage: "exclamationmark.triangle", description: Text("\(location.path)\n\(error)"))
            case .loaded(let location, let rendered):
                VStack(spacing: 0) {
                    if let missingModule {
                        Label("This page belongs to \(missingModule), which is not in your library.", systemImage: "info.circle")
                            .font(.callout)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.quaternary)
                    }
                    PageView(page: rendered.page, openLink: openLink) { reference in
                        // Through the library, so a page's images are kept with it for offline reading.
                        do { return try await library.asset(reference, location.base) } catch {
                            Logger(subsystem: "DocB", category: "images").error("\(reference, privacy: .public): \(error)")
                            return nil
                        }
                    }
                }
            }
        }
    }
}
