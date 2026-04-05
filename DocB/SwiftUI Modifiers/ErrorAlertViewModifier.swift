//
//  ErrorAlertViewModifier.swift
//  VideoPaper
//
//  Created by Testy McTestface on 9/6/25.
//

import SwiftUI

/// Presents a standard error alert whenever a bound optional error is non-`nil`.
///
/// When the alert is dismissed, the bound error is reset to `nil`.
struct ErrorAlertViewModifier: ViewModifier {
    @Binding var errorAlertItem: Error?
    
    private var isShowingErrorAlert: Binding<Bool> {
        Binding {
            errorAlertItem != nil
        } set: { newValue in
            if !newValue {
                errorAlertItem = nil
            }
        }
    }
    
    func body(content: Content) -> some View {
        content
            .alert("Uh Oh", isPresented: isShowingErrorAlert, presenting: errorAlertItem) { _ in
                Button("Ok") {}
            } message: { error in
                Text(error.localizedDescription)
            }
    }
}

/// Convenience API that binds optional errors to the shared alert presentation modifier.
extension View {
    /// Binds a standard "Uh Oh" alert presentation to an optional error value.
    ///
    /// - Parameter error: Optional error binding that controls alert presentation.
    func alert(for error: Binding<Error?>) -> some View {
        modifier(ErrorAlertViewModifier(errorAlertItem: error))
    }
}
