//
//  SettingsView.swift
//  Developer Documentation
//
//  Created by Morris Richman on 12/2/24.
//

import SwiftUI

/// The main settings view for the application.
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

/// A view for configuring general application settings.
struct GeneralSettingsView: View {
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
