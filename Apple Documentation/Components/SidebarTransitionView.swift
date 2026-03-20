//
//  SidebarNavigationView.swift
//  Developer Documentation
//
//  Created by Morris Richman on 3/20/26.
//

import SwiftUI

/// A 2 piece navigation push/pop designed for the sidebar.
///
/// - Warning: When not otherwise using the toolbar, the toolbar size may change between inner and outer views.
struct SidebarNavigationView<OuterView: View, InnerView: View>: View {
    @Binding private var isShowingInnerView: Bool
    private let secondaryShowCondition: Bool
    
    @ViewBuilder private let outerView: OuterView
    @ViewBuilder private let innerView: InnerView
    
    init(isShowingInnerView: Binding<Bool>, secondaryShowCondition: Bool = true, @ViewBuilder outerView: () -> OuterView, @ViewBuilder innerView: () -> InnerView) {
        self._isShowingInnerView = isShowingInnerView
        self.secondaryShowCondition = secondaryShowCondition
        self.outerView = outerView()
        self.innerView = innerView()
    }
    
    var body: some View {
        Group {
            if isShowingInnerView {
                innerView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.move(edge: .trailing))
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Back", systemImage: "chevron.left") {
                                withAnimation(.snappy) {
                                    isShowingInnerView = false
                                }
                            }
                            .labelStyle(.titleAndIcon)
                        }
                    }
            } else {
                outerView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.move(edge: .leading))
            }
        }
        .animation(.default, value: isShowingInnerView)
    }
}

#Preview {
    @Previewable @State var isShowingInnerView = false
    SidebarNavigationView(isShowingInnerView: $isShowingInnerView) {
        VStack {
            Text("Outer View")
            Button("Push") {
                isShowingInnerView.toggle()
            }
        }
    } innerView: {
        Text("Inner View")
    }
}
