//
//  EnvironmentValues.swift
//  DocB
//
//  Created by Morris Richman on 3/11/26.
//

import SwiftUI

extension View {
    /// Injects a custom dismiss closure into environment values for descendant views.
    func customDismiss(_ action: @escaping () -> Void) -> some View {
        environment(\.customDismiss, .init(action: action))
    }
    
    /// Injects an existing dismiss action wrapper into environment values.
    func customDismiss(_ action: CustomDismissAction) -> some View {
        environment(\.customDismiss, action)
    }
}

extension EnvironmentValues {
    /// Dismisses to select anchor view
    @Entry var customDismiss: CustomDismissAction?
    
    @MainActor
    /// Returns the injected dismiss action, or falls back to the system `dismiss` action.
    var customEnabledDismissAction: CustomDismissAction {
        customDismiss ?? CustomDismissAction(action: dismiss.callAsFunction)
    }
    
    @MainActor
    /// Convenience closure for invoking the effective dismiss behavior.
    var customEnabledDismiss: () -> Void {
        customEnabledDismissAction.action
    }
}

/// Wraps a dismiss closure that can be propagated through environment values and compared by identity.
struct CustomDismissAction: Identifiable, Equatable {
    static func == (lhs: CustomDismissAction, rhs: CustomDismissAction) -> Bool {
        lhs.id == rhs.id
    }
    
    let id = UUID()
    let action: () -> Void
}
