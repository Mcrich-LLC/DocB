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
            HeaderImage()
                .padding()
            
            Text("Your Library")
                .font(.headline)
                .fontDesign(.monospaced)
                .foregroundStyle(.secondary)
            
            Text("Welcome To Developer\u{00A0}Documentation")
                .bold()
                .font(.title)
                .minimumScaleFactor(0.7)
            Text("Stop hunting across tabs. Every dependency's documentation, organized in one calm, beautiful place.")
                .foregroundStyle(.primary.opacity(0.5))
            
            Button {
                stepManager.next()
            } label: {
                Label("Get Started", systemSymbol: .arrowRight)
                    .labelStyle(.iconTrailing)
                    .font(.title3)
                    .fontWeight(.black)
                    .fontDesign(.rounded)
                    .padding(.vertical)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.primary)
        }
        .buttonBorderShape(.roundedRectangle)
        .frame(maxWidth: 500)
    }
}

#Preview {
    @Previewable @State var onboardingStepManager = OnboardingStepManager()
    
    IntroOnboardingView()
        .environment(onboardingStepManager)
        .padding(.horizontal)
}

private struct HeaderImage: View {
    @Environment(\.colorScheme) var colorScheme
    
    var baseShadowOpacity: CGFloat {
        colorScheme == .dark ? 0.25 : 0.1
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.OIS_3)
                    .shadow(color: .black.opacity(baseShadowOpacity*3), radius: 5)
                    .padding(.top, 60)
                RoundedRectangle(cornerRadius: 16)
                    .fill(.OIS_2)
                    .shadow(color: .black.opacity(baseShadowOpacity), radius: 5)
                    .padding(20)
                    .padding(.top, 25)
                RoundedRectangle(cornerRadius: 16)
                    .fill(.OIS_1)
                    .shadow(color: .black.opacity(baseShadowOpacity*2), radius: 5)
                    .overlay {
                        VStack {
                            Capsule()
                                .frame(height: 15)
                                .padding(.trailing, 60)
                            Capsule()
                                .fill(.tertiary)
                                .frame(height: 12)
                                .padding(.trailing, 120)
                            Capsule()
                                .fill(.tertiary)
                                .frame(height: 12)
                                .padding(.trailing, 85)
                            Capsule()
                                .fill(.tertiary)
                                .frame(height: 12)
                                .padding(.trailing, 150)
                        }
                        .padding()
                    }
                    .padding(40)
            }
            .padding(.horizontal)
            .aspectRatio(180/140, contentMode: .fit)
            .padding(.top, 35)
            HStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.yellow)
                    .brightness(colorScheme == .dark ? -0.2 : 0)
                    .shadow(radius: 2.5)
                    .overlay(content: {
                        Image(systemSymbol: .squareStack3dUp)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(12)
                    })
                    .frame(width: 50, height: 50)
                Spacer()
            }
            .padding(.top, 45)
            HStack {
                Spacer()
                RoundedRectangle(cornerRadius: 16)
                    .fill(.primary)
                    .shadow(radius: 5)
                    .overlay(content: {
                        Image(systemSymbol: .magnifyingglass)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(20)
                            .foregroundStyle(.primary)
                            .colorInvert()
                    })
                    .frame(width: 65, height: 65)
            }
        }
    }
}
