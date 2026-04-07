//
//  EnvironmentValues.swift
//  DocB
//
//  Created by Morris Richman on 3/11/26.
//

import SwiftUI

extension View {
    /// Injects a custom dismiss closure into environment values for descendant views.
    public func customDismiss(_ action: @escaping @MainActor @Sendable () -> Void) -> some View {
        environment(\.customDismiss, .init(action: action))
    }
    
    /// Injects an existing dismiss action wrapper into environment values.
    public func customDismiss(_ action: CustomDismissAction) -> some View {
        environment(\.customDismiss, action)
    }
}

extension EnvironmentValues {
    /// Dismisses to select anchor view
    public var customDismiss: CustomDismissAction? {
        get { self[CustomDismissKey.self] }
        set { self[CustomDismissKey.self] = newValue }
    }
    
    @MainActor
    /// Returns the injected dismiss action, or falls back to the system `dismiss` action.
    public var customEnabledDismissAction: CustomDismissAction {
        customDismiss ?? CustomDismissAction(action: dismiss.callAsFunction)
    }
    
    @MainActor
    /// Convenience closure for invoking the effective dismiss behavior.
    public var customEnabledDismiss: @MainActor @Sendable () -> Void {
        customEnabledDismissAction.action
    }
}

private struct CustomDismissKey: EnvironmentKey {
    static let defaultValue: CustomDismissAction? = nil
}

/// Wraps a dismiss closure that can be propagated through environment values and compared by identity.
public struct CustomDismissAction: Identifiable, Equatable, Sendable {
    public static func == (lhs: CustomDismissAction, rhs: CustomDismissAction) -> Bool {
        lhs.id == rhs.id
    }
    
    public let id = UUID()
    public let action: @MainActor @Sendable () -> Void
    
    public init(action: @escaping @MainActor @Sendable () -> Void) {
        self.action = action
    }
}
