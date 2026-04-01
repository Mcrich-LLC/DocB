//
//  EnvironmentValues.swift
//  DevDocs
//
//  Created by Morris Richman on 3/11/26.
//

import SwiftUI

extension View {
    func customDismiss(_ action: @escaping () -> Void) -> some View {
        environment(\.customDismiss, .init(action: action))
    }
    
    func customDismiss(_ action: CustomDismissAction) -> some View {
        environment(\.customDismiss, action)
    }
}

extension EnvironmentValues {
    /// Dismisses to select anchor view
    @Entry var customDismiss: CustomDismissAction?
    
    @MainActor
    var customEnabledDismissAction: CustomDismissAction {
        customDismiss ?? CustomDismissAction(action: dismiss.callAsFunction)
    }
    
    @MainActor
    var customEnabledDismiss: () -> Void {
        customEnabledDismissAction.action
    }
}

struct CustomDismissAction: Identifiable, Equatable {
    static func == (lhs: CustomDismissAction, rhs: CustomDismissAction) -> Bool {
        lhs.id == rhs.id
    }
    
    let id = UUID()
    let action: () -> Void
}
