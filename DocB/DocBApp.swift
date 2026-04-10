//
//  Apple_DocumentationApp.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/5/24.
//

import SwiftUI
import SFSafeSymbols
import SwiftData
import DocBCore

/// Application entry point that configures model containers, scenes, and global environments.
@main
struct DocBApp: App {
    /// Shared documentation model injected into app scenes.
    @State var documentationViewModel = DocumentationViewModel()
    /// Shared app settings model injected into app scenes.
    @State var appSettings = AppSettings()
    /// Controls add-source sheet presentation on non-macOS platforms.
    @State private var showAddSource = false
    @Environment(\.openWindow) var openWindow
    /// Primary SwiftData container for docs, bookmarks, and collections.
    let docCSiteModelContainer: ModelContainer
    
    /// Initializes the SwiftData container and development-only integrations.
    init() {
        do {
            docCSiteModelContainer = try ModelContainer(for: DocCSite.self, Bookmark.self, BookmarkCollection.self, configurations: .init(cloudKitDatabase: .automatic))
        } catch {
            fatalError("Error Initializing ModelContainer: \(error)")
        }
        
        loadRocketSimConnect()
    }
    
    var body: some Scene {
        WindowGroup(id: WindowTypes.main, for: URL.self) { url in
            MainView(url: url.wrappedValue, showAddSource: $showAddSource)
        } defaultValue: {
            URL(string: "doc://")!
        }
        .modelContainer(docCSiteModelContainer)
        .environment(documentationViewModel)
        .environment(appSettings)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Window", action: { openWindow(id: WindowTypes.main) })
                    .keyboardShortcut(.init("n"), modifiers: .command)
                Button("Add Source", action: showAddDocumentationView)
                    .keyboardShortcut(.init("n"), modifiers: [.command, .shift])
            }
        }
        
        #if os(macOS)
        Window("Add Source", id: WindowTypes.addSites) {
            AddTechnologyView()
        }
        .modelContainer(docCSiteModelContainer)
        .environment(documentationViewModel)
        .environment(appSettings)
        Settings {
            SettingsView()
        }
        .environment(documentationViewModel)
        .environment(appSettings)
        #endif
    }
    
    /// Loads RocketSim debug integration when available in local development environments.
    private func loadRocketSimConnect() {
        #if DEBUG
        guard (Bundle(path: "/Applications/RocketSim.app/Contents/Frameworks/RocketSimConnectLinker.nocache.framework")?.load() == true) else {
            print("Failed to load linker framework")
            return
        }
        print("RocketSim Connect successfully linked")
        #endif
    }
    
    /// Presents the add-source experience using platform-appropriate presentation.
    private func showAddDocumentationView() {
        #if os(macOS)
        openWindow(id: WindowTypes.addSites)
        #else
        showAddSource = true
        #endif
    }
}

/// Root scene container that switches between onboarding and main content flows.
private struct MainView: View {
    /// Onboarding completion flag persisted across launches.
    @AppStorage("has_onboarded") private var hasOnboarded: Bool = false
    /// Initial URL value passed into this window scene.
    let url: URL
    /// Binding controlling add-source presentation state.
    @Binding var showAddSource: Bool
    
    @Environment(DocumentationViewModel.self) private var documentationViewModel
    @Environment(\.modelContext) var modelContext
    @Environment(\.appearsActive) var appearsActive
    /// Persisted custom DocC sites backing loaded technologies.
    @Query private var docCSites: [DocCSite]
    
    /// Tracks source-sheet visibility only while the owning scene is active.
    var activeTrackedShowAddSource: Binding<Bool> {
        Binding {
            appearsActive && self.showAddSource
        } set: { newValue in
            showAddSource = newValue
        }

    }
    
    var body: some View {
        VStack {
            switch hasOnboarded {
            case true:
                ContentView(url: url)
                    .backForward(isBack: false)
            case false:
                MainOnboardingView()
                    .backForward(isBack: false)
                    .customDismiss {
                        hasOnboarded = true
                    }
            }
        }
        .animation(.default, value: hasOnboarded)
        .task {
            await documentationViewModel.loadTechnologies(docCSites.asDTOs)
        }
        .onChange(of: docCSites, onSwiftDataChange)
        .sheet(isPresented: activeTrackedShowAddSource) {
            AddTechnologySheetView()
        }
    }
    
    /// Synchronizes in-memory technologies with SwiftData changes.
    private func onSwiftDataChange(oldValue: [DocCSite], newValue: [DocCSite]) {
        Task {
            await documentationViewModel.loadTechnologies(newValue.asDTOs)
        }
        Task {
            for value in oldValue where !newValue.contains(where: { $0.id == value.id }) {
                try? documentationViewModel.deleteTechnology(.docC(value.dto), modelContext: modelContext)
            }
        }
    }
}
