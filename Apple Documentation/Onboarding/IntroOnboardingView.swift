//
//  IntroOnboardingView.swift
//  Developer Documentation
//
//  Created by Morris Richman on 1/15/26.
//

import SwiftUI

struct IntroOnboardingView: View {
    @Environment(OnboardingStepManager.self) var stepManager
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Welcome To Developer Documentation")
                .bold()
                .font(.title)
            Text("It seems as though every single dependancy has its own documentation in different places with varying degrees of pleasing UI. That all changes with Developer Documentation. Add your dependencies and organize documentation all in one place.")
                .frame(maxWidth: .infinity)
            
            HStack {
                Button("Get Started") {
                    stepManager.next()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .buttonBorderShape(.capsule)
    }
}

#Preview {
    IntroOnboardingView()
}
