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
    @ObservedObject var documentationViewModel = DocumentationViewModel()
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [DocCSite.self], isAutosaveEnabled: true)
        .environmentObject(documentationViewModel)
        
        #if os(macOS)
        Settings {
            SettingsView()
        }
        .environmentObject(documentationViewModel)
        #endif
    }
}
