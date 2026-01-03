//
//  SettingsView.swift
//  Developer Documentation
//
//  Created by Morris Richman on 12/2/24.
//

import SwiftUI

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

struct GeneralSettingsView: View {
    @State var navigationViewModel: NavigationViewModel = .init()
    
    var body: some View {
        VStack {
            Toggle("Open Article in New Window", isOn: $navigationViewModel.openInAppDeeplinksInNewWindow)
        }
    }
}

#Preview {
    SettingsView()
}
