//
//  SelectedLineBackground.swift
//  DocB
//
//  Created by Morris Richman on 1/27/26.
//

import SwiftUI

/// Rounded background highlight used for selected rows in sidebar-like lists.
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
    
    /// Applies the selected-line background treatment when running in split-view navigation mode.
    ///
    /// - Parameter isSelected: Whether the current row should render as selected.
    @ViewBuilder
    func selectedLineBackground(isSelected: Bool) -> some View {
        modifier(SelectedLineBackgroundModifier(isSelected: isSelected))
    }
}

private struct SelectedLineBackgroundModifier: ViewModifier {
    let isSelected: Bool
    @Environment(NavigationViewModel.self) var navigationViewModel
    
    /// Only applies selected-row highlighting while split-view navigation is active.
    func body(content: Content) -> some View {
        if navigationViewModel.isUsingSplitView {
            content
                .background(SelectedLineBackground(isSelected: isSelected))
        } else {
            content
        }
    }
}
