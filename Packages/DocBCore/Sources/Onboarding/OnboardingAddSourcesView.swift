//
//  OnboardingAddSourcesView.swift
//  DocB
//
//  Created by Morris Richman on 1/15/26.
//

import SwiftUI

/// Displays the onboarding step where users add documentation sources before finishing setup.
struct OnboardingAddSourcesView: View {
    @Environment(OnboardingStepManager.self) var stepManager
    @State private var isVisible = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Customize DocB")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentColor)
                    .textCase(.uppercase)
                
                Text("Add Some Sources")
                    .font(.system(.largeTitle, weight: .bold))
                    .foregroundStyle(.primary)
            }
            .offset(y: isVisible ? 0 : 20)
            .opacity(isVisible ? 1 : 0)
            .animation(.easeOut(duration: 0.6).delay(0.2), value: isVisible)
            
            AddTechnologyView()
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
                .offset(y: isVisible ? 0 : 20)
                .opacity(isVisible ? 1 : 0)
                .animation(.easeOut(duration: 0.6).delay(0.4), value: isVisible)
        }
        .frame(maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            Button {
                stepManager.next()
            } label: {
                Text("Done")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(Color.primary)
                    .colorInvert()
            }
            .buttonStyle(.borderedProminent)
            .tintColor(Color.primary)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .shadow(color: .primary.opacity(0.15), radius: 8, y: 4)
            .offset(y: isVisible ? 0 : 30)
            .opacity(isVisible ? 1 : 0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.6), value: isVisible)
        }
        .onAppear {
            isVisible = true
        }
    }
}

#Preview {
    @Previewable @State var documentationViewModel: DocumentationViewModel = .init()
    @Previewable @State var onboardingStepManager: OnboardingStepManager = .init()
    OnboardingAddSourcesView()
        .environment(documentationViewModel)
        .environment(onboardingStepManager)
        .modelContainer(for: [DocCSite.self], isAutosaveEnabled: true)
        .padding(.horizontal)
}
