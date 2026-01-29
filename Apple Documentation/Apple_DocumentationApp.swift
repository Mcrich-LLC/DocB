//
//  Apple_DocumentationApp.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/5/24.
//

import SwiftUI
@_exported import SFSafeSymbols
import SwiftData

@main
struct Apple_DocumentationApp: App {
    @State var documentationViewModel = DocumentationViewModel()
    @State var appSettings = AppSettings()
    
    init() {
        loadRocketSimConnect()
    }
    
    var body: some Scene {
        WindowGroup(for: URL.self) { url in
            ContentView(url: url.wrappedValue)
        } defaultValue: {
            URL(string: "doc://")!
        }
        .modelContainer(for: [DocCSite.self], isAutosaveEnabled: true)
        .environment(documentationViewModel)
        .environment(appSettings)
        
        #if os(macOS)
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
