//
//  SettingsView.swift
//  DocB
//
//  Created by Morris Richman on 12/2/24.
//

import SwiftUI

/// Renders the app settings container and organizes settings into tabs.
struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gear") {
                GeneralSettingsView()
            }
        }
        .padding()
        .frame(minWidth: 400)
    }
}

/// Shows general app preferences, including default article window behavior.
struct GeneralSettingsView: View {
    /// Global app settings model bound to controls in this view.
    @Environment(AppSettings.self) var appSettings
    
    var body: some View {
        @Bindable var appSettings = appSettings
        VStack {
            Toggle("Open Article in New Window", isOn: $appSettings.openInAppDeeplinksInNewWindow)
        }
    }
}

#Preview {
    SettingsView()
}
