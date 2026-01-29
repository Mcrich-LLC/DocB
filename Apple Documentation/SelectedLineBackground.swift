//
//  SelectedLineBackground.swift
//  Developer Documentation
//
//  Created by Morris Richman on 1/27/26.
//

import SwiftUI

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
