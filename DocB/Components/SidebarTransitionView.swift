//
//  SidebarNavigationView.swift
//  DocB
//
//  Created by Morris Richman on 3/20/26.
//

import SwiftUI

/// A 2 piece navigation push/pop designed for the sidebar.
///
/// - Warning: When not otherwise using the toolbar, the toolbar size may change between inner and outer views.
struct SidebarNavigationView<OuterView: View, InnerView: View, P>: View {
    @Binding private var apiExposedisShowingInnerView: Bool
    private let unwrappedOptional: P?
    
    @ViewBuilder private let outerView: OuterView
    @ViewBuilder private let innerView: (P) -> InnerView
    
    init(isShowingInnerView: Binding<Bool>, unwrapping: P?, @ViewBuilder outerView: () -> OuterView, @ViewBuilder innerView: @escaping (P) -> InnerView) {
        self._apiExposedisShowingInnerView = isShowingInnerView
        self.isShowingInnerView = isShowingInnerView.wrappedValue
        self.unwrappedOptional = unwrapping
        self.outerView = outerView()
        self.innerView = innerView
    }
    
    init(isShowingInnerView: Binding<Bool>, @ViewBuilder outerView: () -> OuterView, @ViewBuilder innerView: @escaping () -> InnerView) where P == Bool {
        self._apiExposedisShowingInnerView = isShowingInnerView
        self.isShowingInnerView = isShowingInnerView.wrappedValue
        self.unwrappedOptional = true
        self.outerView = outerView()
        self.innerView = { _ in innerView() }
    }
    
    @State private var isHidingBackToolbarButton = false
    @State private var isShowingInnerView: Bool
    @State private var isBack: Bool = false
    
    var body: some View {
        outerView
            .overlay {
                if isShowingInnerView, let unwrappedOptional {
                    innerContent(unwrappedOptional)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.background)
                }
            }
        .animation(.default, value: isShowingInnerView)
        .onChange(of: apiExposedisShowingInnerView) { oldValue, newValue in
            if oldValue && !newValue {
                isBack = true
            } else {
                isBack = false
            }
            withAnimation(.snappy) {
                isShowingInnerView = newValue
            }
        }
    }
    
    @ViewBuilder
    func innerContent(_ unwrappedOptional: P) -> some View {
        innerView(unwrappedOptional)
            .onPreferenceChange(HideBackPreferenceKey.self) { isHiding in
                isHidingBackToolbarButton = isHiding
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
//                    .backForward(isBack: isBack)
            .toolbar {
                if !isHidingBackToolbarButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Back", systemImage: "chevron.left") {
                            apiExposedisShowingInnerView = false
                        }
                        .labelStyle(.titleAndIcon)
                    }
                }
            }
            .preference(key: HideBackPreferenceKey.self, value: true)
    }
}

/// Preference key used by nested sidebar content to hide/show the back toolbar button.
private struct HideBackPreferenceKey: PreferenceKey {
    static let defaultValue: Bool = false

    /// Keeps the most recent preference value emitted from inner content.
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = nextValue() // Overwrite with the latest value
    }
}

#if DEBUG
/// Debug preview host used to manually verify nested sidebar push/pop behavior.
private struct ProviderView: View {
    @State var isShowingInnerView = false
    @State var isShowingInnerView2 = false
    
    var body: some View {
        SidebarNavigationView(isShowingInnerView: $isShowingInnerView) {
            VStack {
                Text("Outer View")
                Button("Push") {
                    isShowingInnerView.toggle()
                }
            }
        } innerView: {
            SidebarNavigationView(isShowingInnerView: $isShowingInnerView2) {
                VStack {
                    Text("Inner Outer View")
                    Button("Push") {
                        isShowingInnerView2.toggle()
                    }
                }
            } innerView: {
                Text("Inner Inner View")
            }
        }
    }
}

#Preview {
    ProviderView()
}
#endif
