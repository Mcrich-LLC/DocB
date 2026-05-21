//
//  MainOnboardingView.swift
//  Teddy
//
//  Created by Morris Richman on 1/15/26.
//

import SwiftUI

/// Tracks onboarding step progression and controls forward/back navigation and dismissal.
@Observable
final class OnboardingStepManager {
    /// Dismiss action called when onboarding reaches its final step.
    fileprivate var dismiss: CustomDismissAction = .init(action: {})
    
    /// Current onboarding step.
    private(set) var step: OnboardingSteps = .intro
    /// Transition direction flag used for back/forward animations.
    var isBack = false
    
    /// Advances to the next onboarding step or dismisses when complete.
    @MainActor func next() {
        isBack = false
        guard step.rawValue < OnboardingSteps.allCases.count - 1 else {
            dismiss.action()
            return
        }
        
        withAnimation {
            step.next()
        }
    }
    /// Moves to the previous onboarding step.
    func previous() {
        isBack = true
        withAnimation {
            step.previous()
        }
    }
}

/// Enumerates the ordered onboarding screens shown to the user.
enum OnboardingSteps: Int, ViewSteps {
    case intro, addSources
}

/// Hosts the onboarding flow and swaps step content based on the active onboarding state.
public struct MainOnboardingView: View {
    /// Local step manager controlling onboarding flow state.
    @State var stepManager = OnboardingStepManager()
    @Environment(\.customEnabledDismissAction) var customEnabledDismissAction
    
    public init() {}
    
    public var body: some View {
        VStack {
            switch stepManager.step {
            case .intro:
                IntroOnboardingView()
                    .padding()
                    .fillSpaceAvailable()
                    .backForward(isBack: stepManager.isBack)
            case .addSources:
                OnboardingAddSourcesView()
                    .padding()
                    .fillSpaceAvailable()
                    .backForward(isBack: stepManager.isBack)
            }
        }
        .environment(stepManager)
        .onChange(of: customEnabledDismissAction, initial: true) { _, newValue in
            stepManager.dismiss = newValue
        }
    }
}
