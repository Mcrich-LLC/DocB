//
//  SettingsView.swift
//  DocB
//
//  Created by Morris Richman on 12/2/24.
//

import SwiftUI

/// Renders the app settings container and organizes settings into tabs.
public struct SettingsView: View {
    public init() {}
    
    public var body: some View {
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
