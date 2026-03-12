//
//  Apple_DocumentationApp.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/5/24.
//

import SwiftUI
@_exported import SFSafeSymbols
import SwiftData

struct WindowTypes {
    static let addSites = "add_sites"
}

@main
struct Apple_DocumentationApp: App {
    @State var documentationViewModel = DocumentationViewModel()
    @State var appSettings = AppSettings()
    let docCSiteModelContainer: ModelContainer
    
    init() {
        do {
            docCSiteModelContainer = try ModelContainer(for: DocCSite.self, configurations: .init(cloudKitDatabase: .automatic))
        } catch {
            fatalError("Error Initializing ModelContainer: \(error)")
        }
        
        loadRocketSimConnect()
    }
    
    var body: some Scene {
        WindowGroup(for: URL.self) { url in
            MainView(url: url.wrappedValue)
        } defaultValue: {
            URL(string: "doc://")!
        }
        .modelContainer(docCSiteModelContainer)
        .environment(documentationViewModel)
        .environment(appSettings)
        
        #if os(macOS)
        Window("Add Sources", id: WindowTypes.addSites) {
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
    
    private func loadRocketSimConnect() {
        #if DEBUG
        guard (Bundle(path: "/Applications/RocketSim.app/Contents/Frameworks/RocketSimConnectLinker.nocache.framework")?.load() == true) else {
            print("Failed to load linker framework")
            return
        }
        print("RocketSim Connect successfully linked")
        #endif
    }
}

private struct MainView: View {
    @AppStorage("has_onboarded") var hasOnboarded: Bool = false
    let url: URL
    
    @Environment(DocumentationViewModel.self) private var documentationViewModel
    @Environment(\.modelContext) var modelContext
    @Query private var docCSites: [DocCSite]
    
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
    }
    
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
