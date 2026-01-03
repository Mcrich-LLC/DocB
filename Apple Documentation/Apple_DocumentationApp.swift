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
    
    init() {
        loadRocketSimConnect()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [DocCSite.self], isAutosaveEnabled: true)
        .environment(documentationViewModel)
        
        #if os(macOS)
        Settings {
            SettingsView()
        }
        .environment(documentationViewModel)
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
