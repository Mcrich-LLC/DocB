//
//  Apple_DocumentationApp.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/5/24.
//

import SwiftUI
import SwiftData
import DocBCore
import FactoryKit
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// Application entry point that configures model containers, scenes, and global environments.
@main
struct DocBApp: App {
#if canImport(UIKit) && !os(watchOS)
    @UIApplicationDelegateAdaptor(DocBAppDelegate.self) private var appDelegate
#endif
#if canImport(AppKit)
    @NSApplicationDelegateAdaptor(DocBMacAppDelegate.self) private var macAppDelegate
#endif
    /// Shared documentation model injected into app scenes.
    @State var documentationViewModel: DocumentationViewModel
    /// Shared app settings model injected into app scenes.
    @State var appSettings: AppSettings
    /// Controls add-source sheet presentation on non-macOS platforms.
    @State private var showAddSource = false
    @Environment(\.openWindow) var openWindow
    /// Primary SwiftData container for docs, bookmarks, and collections.
    let docCSiteModelContainer: ModelContainer
    /// Explicit CloudKit sync coordinator backed by MYCloudKit.
    let cloudSyncEngine: DocBCloudSyncEngine
    
    /// Initializes the SwiftData container and development-only integrations.
    init() {
        #if canImport(UIKit)
        UIApplication.shared.registerForRemoteNotifications()
        #endif
        #if canImport(AppKit)
        NSApplication.shared.registerForRemoteNotifications()
        #endif
        
        let container = Container.shared
        docCSiteModelContainer = container.docBModelContainer()
        cloudSyncEngine = container.docBCloudSyncEngine()
        documentationViewModel = container.documentationViewModel()
        appSettings = container.appSettings()
        
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
        .environment(cloudSyncEngine)
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
                .frame(minWidth: 400, minHeight: 300)
        }
        .modelContainer(docCSiteModelContainer)
        .environment(documentationViewModel)
        .environment(appSettings)
        .environment(cloudSyncEngine)
        Settings {
            SettingsView()
        }
        .environment(documentationViewModel)
        .environment(appSettings)
        .environment(cloudSyncEngine)
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
    @Environment(DocBCloudSyncEngine.self) private var cloudSyncEngine
    @Environment(\.appearsActive) var appearsActive
    @Environment(\.scenePhase) private var scenePhase
    /// Persisted custom DocC sites backing loaded technologies.
    @Query private var docCSites: [DocCSite]
    /// Persisted bookmark collections that participate in explicit CloudKit sync.
    @Query private var bookmarkCollections: [BookmarkCollection]
    /// Persisted bookmarks that participate in explicit CloudKit sync.
    @Query private var bookmarks: [Bookmark]
    
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
            cloudSyncEngine.syncAll(docCSites: docCSites, collections: bookmarkCollections, bookmarks: bookmarks)
            await cloudSyncEngine.start()
            await documentationViewModel.loadTechnologies(docCSites.asPersistedDocCSources)
        }
        .onChange(of: docCSiteSnapshots, onSwiftDataChange)
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            Task {
                await cloudSyncEngine.fetchRemoteChanges()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .docBCloudKitRemoteNotificationReceived)) { _ in
            Task {
                await cloudSyncEngine.fetchRemoteChanges()
            }
        }
        .onChange(of: bookmarkCollections) { oldValue, newValue in
            cloudSyncEngine.syncBookmarkCollectionChanges(oldValue: oldValue, newValue: newValue)
        }
        .onChange(of: bookmarks) { oldValue, newValue in
            cloudSyncEngine.syncBookmarkChanges(oldValue: oldValue, newValue: newValue)
        }
        .sheet(isPresented: activeTrackedShowAddSource) {
            AddTechnologySheetView()
        }
    }
    
    /// Lightweight DocC site metadata observed for inserts, deletes, and sync updates.
    private var docCSiteSnapshots: [DocCSiteSnapshot] {
        docCSites.snapshots
    }
    
    /// Synchronizes in-memory technologies with SwiftData changes.
    private func onSwiftDataChange(oldValue: [DocCSiteSnapshot], newValue: [DocCSiteSnapshot]) {
        cloudSyncEngine.syncDocCSiteChanges(oldValue: oldValue, newValue: newValue)
        
        let oldIDs = Set(oldValue.map(\.id))
        let newIDs = Set(newValue.map(\.id))
        let insertedSites = newValue.filter { !oldIDs.contains($0.id) }
        
        if !insertedSites.isEmpty {
            Task {
                await documentationViewModel.loadTechnologies(insertedSites.asPersistedDocCSources)
            }
        }
        
        for value in oldValue where !newIDs.contains(value.id) {
            documentationViewModel.removeTechnologyFromMemory(id: value.id, url: value.url)
        }
    }
}

// MARK: – App Delegates
#if canImport(UIKit) && !os(watchOS)
/// Forwards CloudKit remote-change pushes into DocB's explicit MYCloudKit sync engine.
private final class DocBAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable : Any]
    ) async -> UIBackgroundFetchResult {
        NotificationCenter.default.post(
            name: .docBCloudKitRemoteNotificationReceived,
            object: nil,
            userInfo: userInfo
        )
        
        return .newData
    }
}
#endif

#if canImport(AppKit)
/// Forwards macOS CloudKit remote-change pushes into DocB's explicit MYCloudKit sync engine.
private final class DocBMacAppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String : Any]) {
        NotificationCenter.default.post(
            name: .docBCloudKitRemoteNotificationReceived,
            object: nil,
            userInfo: userInfo
        )
    }
}
#endif
