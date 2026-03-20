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
struct SidebarNavigationView<OuterView: View, InnerView: View, P>: View {
    @Binding private var isShowingInnerView: Bool
    private let unwrappedOptional: P?
    
    @ViewBuilder private let outerView: OuterView
    @ViewBuilder private let innerView: (P) -> InnerView
    
    init(isShowingInnerView: Binding<Bool>, unwrapping: P?, @ViewBuilder outerView: () -> OuterView, @ViewBuilder innerView: @escaping (P) -> InnerView) {
        self._isShowingInnerView = isShowingInnerView
        self.unwrappedOptional = unwrapping
        self.outerView = outerView()
        self.innerView = innerView
    }
    
    init(isShowingInnerView: Binding<Bool>, @ViewBuilder outerView: () -> OuterView, @ViewBuilder innerView: @escaping () -> InnerView) where P == Bool {
        self._isShowingInnerView = isShowingInnerView
        self.unwrappedOptional = true
        self.outerView = outerView()
        self.innerView = { _ in innerView() }
    }
    
    var body: some View {
        Group {
            if isShowingInnerView, let unwrappedOptional {
                innerView(unwrappedOptional)
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
