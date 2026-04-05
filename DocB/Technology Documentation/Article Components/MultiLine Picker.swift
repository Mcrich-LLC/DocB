//
//  MultiLine Picker.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/9/24.
//

import SwiftUI

/// MultilinePicker renders a reusable SwiftUI view.
struct MultilinePicker<Cell, Data>: View where Cell: View, Data: RandomAccessCollection, Data.Element: Identifiable, Data.Element: Equatable {
    /// Options shown by the picker.
    let data: Data
    /// Current selection binding.
    @Binding var selection: Data.Element
    
    /// Cell builder used to render each option.
    @ViewBuilder let cell: (Data.Element) -> Cell
    /// Namespace used for matched-geometry selection marker animation.
    @Namespace private var ns
    
    /// Horizontal shadow offset for the selected marker at segment edges.
    var xShadow: CGFloat {
        guard let index = data.firstIndex(of: selection) as? Int else { return 0 }
        
        if index == 0 {
            return 1
        } else if index == data.count-1 {
            return -1
        } else {
            return 0
        }
    }
    
    /// Corner radius used by segment backgrounds.
    private let cornerRadius: CGFloat = 6
    /// Current color scheme used by selection background color logic.
    @Environment(\.colorScheme) var colorScheme
    
    /// Filled background color for the currently selected segment.
    var selectedBackgroundColor: Color {
        #if os(macOS)
        Color(platformColor: .windowBackgroundColor)
        #else
        switch colorScheme {
        case .light: Color(platformColor: .systemBackground)
        case .dark: Color(platformColor: .systemGray2)
        @unknown default: Color(platformColor: .systemBackground)
        }
        #endif
    }
    
    /// Unselected segmented-control background color.
    let backgroundColor: Color = Color(platformColor: .secondarySystemFill)

    var body: some View {
        HStack(spacing: 0) {
            ForEach(data) { item in
                let index = data.firstIndex(of: item) as? Int
                let selectionIndex = data.firstIndex(of: selection) as? Int
                
                if let index, let selectionIndex, (index < selectionIndex || index > selectionIndex+1), data.first != item {
                    Divider()
                }
                
                ZStack {
                    Group {
                        if selection.id == item.id {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(selectedBackgroundColor)
                                .frame(maxHeight: .infinity)
                                .matchedGeometryEffect(id: "Marker", in: ns)
                                .shadow(color: .black.opacity(0.2), radius: 0.5, x: xShadow, y: 0.7)
                        } else {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(backgroundColor.opacity(0.00000000001))
                                .frame(maxHeight: .infinity)
                        }
                    }
                    
                    cell(item)
                        .bold(selection.id == item.id)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .onTapGesture {
                    selection = item
                }
            }
        }
        .animation(.linear(duration: 0.25), value: selection.id)
        .fixedSize(horizontal: false, vertical: true)
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 8).fill(backgroundColor))
    }
}
