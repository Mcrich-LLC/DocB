//
//  SelectedLineBackground.swift
//  Developer Documentation
//
//  Created by Morris Richman on 1/27/26.
//

import SwiftUI

/// A view that draws a standard background for selected items in a list or sidebar.
struct SelectedLineBackground: View {
    let isSelected: Bool
    
    private let cornerRadius: CGFloat = {
        if #available(iOS 26, macOS 26, *) {
            22.5
        } else {
            12
        }
    }()
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .selectedLineBackgroundPadding()
            .foregroundStyle(Color(platformColor: .tertiarySystemFill))
            .opacity(isSelected ? 1 : 0)
    }
}

extension View {
    @ViewBuilder
    fileprivate func selectedLineBackgroundPadding() -> some View {
        if #available(iOS 26, macOS 26, *) {
            self
                .padding(.horizontal, -10)
                .padding(.vertical, -4)
        } else {
            self.padding(-10)
        }
    }
    
    /// Applies a standard selected background style to the view.
    ///
    /// - Parameter isSelected: A Boolean value indicating whether the item is selected.
    /// - Returns: A view with the selected background applied if `isSelected` is true.
    @ViewBuilder
    func selectedLineBackground(isSelected: Bool) -> some View {
        modifier(SelectedLineBackgroundModifier(isSelected: isSelected))
    }
}

private struct SelectedLineBackgroundModifier: ViewModifier {
    let isSelected: Bool
    @Environment(NavigationViewModel.self) var navigationViewModel
    
    func body(content: Content) -> some View {
        if navigationViewModel.isUsingSplitView {
            content
                .background(SelectedLineBackground(isSelected: isSelected))
        } else {
            content
        }
    }
}
