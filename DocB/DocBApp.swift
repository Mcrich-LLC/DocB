//
//  Apple_DocumentationApp.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/5/24.
//

import SwiftUI
@_exported import SFSafeSymbols
import SwiftData

/// Scene and window identifiers used by the app.
struct WindowTypes {
    /// Secondary window for adding custom DocC sources.
    static let addSites = "add_sites"
    /// Main documentation browsing window.
    static let main = "main"
}

@main
/// Application entry point that configures model containers, scenes, and global environments.
struct DocBApp: App {
    @State var documentationViewModel = DocumentationViewModel()
    @State var appSettings = AppSettings()
    @State private var showAddSource = false
    @Environment(\.openWindow) var openWindow
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

private struct MainView: View {
    @AppStorage("has_onboarded") private var hasOnboarded: Bool = false
    let url: URL
    @Binding var showAddSource: Bool
    
    @Environment(DocumentationViewModel.self) private var documentationViewModel
    @Environment(\.modelContext) var modelContext
    @Environment(\.appearsActive) var appearsActive
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
