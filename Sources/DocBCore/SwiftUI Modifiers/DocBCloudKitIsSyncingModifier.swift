//
//  DocBCloudKitIsSyncingModifier.swift
//  DocBCore
//
//  Created by Morris Richman on 4/12/26.
//

import SwiftUI

/// A modifier that tracks whether DocB's explicit MYCloudKit sync engine is active.
private struct DocBCloudKitIsSyncingModifier: ViewModifier {
    @Environment(DocBCloudSyncEngine.self) private var cloudSyncEngine

    /// The externally exposed boolean variable describing the sync state.
    @Binding var isSyncing: Bool
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                isSyncing = cloudSyncEngine.isSyncing
            }
            .onChange(of: cloudSyncEngine.isSyncing) { _, newValue in
                isSyncing = newValue
            }
    }
}

extension View {
    /// Tracks whether DocB's explicit MYCloudKit sync engine is active.
    public func isDocBCloudKitSyncing(_ isSyncing: Binding<Bool>) -> some View {
        modifier(DocBCloudKitIsSyncingModifier(isSyncing: isSyncing))
    }
}
