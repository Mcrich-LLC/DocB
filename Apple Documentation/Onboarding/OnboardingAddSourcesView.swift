//
//  OnboardingAddSourcesView.swift
//  Developer Documentation
//
//  Created by Morris Richman on 1/15/26.
//

import SwiftUI

struct OnboardingAddSourcesView: View {
    @Environment(OnboardingStepManager.self) var stepManager
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Add Some Sources")
                .bold()
                .font(.title)
            
            AddTechnologyView()
                .listStyle(.inset)
//                .listRowBackground(Color(platformColor: .secondarySystemGroupedBackground))
//                .backgroundStyle(.background.secondary)
                .scrollContentBackground(.hidden)
//                .frame(maxWidth: 500)
            
            Button {
                stepManager.next()
            } label: {
                Text("Done")
                    .labelStyle(.iconTrailing)
                    .font(.title3)
                    .fontWeight(.black)
                    .fontDesign(.rounded)
                    .padding(.vertical)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.primary)
        }
        .buttonBorderShape(.roundedRectangle)
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
