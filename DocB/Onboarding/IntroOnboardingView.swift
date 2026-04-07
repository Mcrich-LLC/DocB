//
//  IntroOnboardingView.swift
//  DocB
//
//  Created by Morris Richman on 1/15/26.
//

import SwiftUI

/// Presents the opening onboarding screen that introduces the app and advances to the next step.
struct IntroOnboardingView: View {
    @Environment(OnboardingStepManager.self) var stepManager
    @State private var isVisible = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ViewThatFits {
                HeaderImage()
                    .frame(minWidth: 250, minHeight: 250)
                    .layoutPriority(-1)
                    .padding(.bottom, 20)
                Text("").accessibilityHidden(true)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Your Library")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentColor)
                    .textCase(.uppercase)
                
                Text("Welcome to DocB")
                    .font(.system(.largeTitle, weight: .bold))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.7)
                
                Text("Stop hunting across tabs. Every dependency's documentation, organized in one calm, beautiful place.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .padding(.top, 4)
            }
            .offset(y: isVisible ? 0 : 20)
            .opacity(isVisible ? 1 : 0)
            .animation(.easeOut(duration: 0.6).delay(0.5), value: isVisible)
        }
        .frame(maxWidth: 500, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            Button {
                stepManager.next()
            } label: {
                Label("Get Started", systemSymbol: .arrowRight)
                    .labelStyle(.iconTrailing)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(Color.primary)
                    .colorInvert()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.primary)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .shadow(color: .primary.opacity(0.15), radius: 8, y: 4)
            .offset(y: isVisible ? 0 : 30)
            .opacity(isVisible ? 1 : 0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.7), value: isVisible)
        }
        .onAppear {
            isVisible = true
        }
    }
}

#Preview {
    @Previewable @State var onboardingStepManager = OnboardingStepManager()
    
    IntroOnboardingView()
        .environment(onboardingStepManager)
        .padding(.horizontal)
}

/// Decorative stacked-card hero image used at the top of intro onboarding.
private struct HeaderImage: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var isVisible = false
    @State private var isFloating = false
    
    var baseShadowOpacity: CGFloat {
        colorScheme == .dark ? 0.25 : 0.1
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.OIS_3)
                    .shadow(color: .black.opacity(baseShadowOpacity * 3), radius: 5)
                    .padding(.top, 60)
                    .offset(y: isVisible ? 0 : 50)
                    .scaleEffect(isVisible ? 1 : 0.8)
                    .opacity(isVisible ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: isVisible)
                
                RoundedRectangle(cornerRadius: 16)
                    .fill(.OIS_2)
                    .shadow(color: .black.opacity(baseShadowOpacity), radius: 5)
                    .padding(20)
                    .padding(.top, 25)
                    .offset(y: isVisible ? 0 : 30)
                    .scaleEffect(isVisible ? 1 : 0.85)
                    .opacity(isVisible ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: isVisible)
                
                RoundedRectangle(cornerRadius: 16)
                    .fill(.OIS_1)
                    .shadow(color: .black.opacity(baseShadowOpacity * 2), radius: 5)
                    .overlay {
                        VStack(alignment: .leading) {
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
                        .opacity(isVisible ? 1 : 0)
                        .padding()
                    }
                    .padding(40)
                    .offset(y: isVisible ? 0 : 15)
                    .scaleEffect(isVisible ? 1 : 0.9)
                    .opacity(isVisible ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: isVisible)
            }
            .padding(.horizontal)
            .aspectRatio(180/140, contentMode: .fit)
            .padding(.top, 35)
            .overlay {
                GeometryReader { geo in
                    let icon1Size = max(40, geo.size.width * 0.16)
                    let icon2Size = max(50, geo.size.width * 0.20)
                    
                    RoundedRectangle(cornerRadius: icon1Size * 0.2)
                        .fill(.yellow)
                        .brightness(colorScheme == .dark ? -0.2 : 0)
                        .shadow(radius: 2.5)
                        .overlay {
                            Image(systemSymbol: .squareStack3dUp)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .padding(icon1Size * 0.25)
                        }
                        .frame(width: icon1Size, height: icon1Size)
                        .position(x: icon1Size * 0.6, y: geo.size.height * 0.25)
                        .offset(y: isFloating ? -8 : 8)
                        .rotationEffect(.degrees(isFloating ? -4 : 4))
                        .scaleEffect(isVisible ? 1 : 0.01)
                        .opacity(isVisible ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.4), value: isVisible)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isFloating)
                    
                    RoundedRectangle(cornerRadius: icon2Size * 0.25)
                        .fill(.primary)
                        .shadow(radius: 5)
                        .overlay {
                            Image(systemSymbol: .magnifyingglass)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .padding(icon2Size * 0.3)
                                .foregroundStyle(.primary)
                                .colorInvert()
                        }
                        .frame(width: icon2Size, height: icon2Size)
                        .position(x: geo.size.width - icon2Size * 0.4, y: geo.size.height * 0.75)
                        .offset(y: isFloating ? 10 : -10)
                        .rotationEffect(.degrees(isFloating ? 5 : -5))
                        .scaleEffect(isVisible ? 1 : 0.01)
                        .opacity(isVisible ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.5), value: isVisible)
                        .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: isFloating)
                }
            }
        }
        .onAppear {
            isVisible = true
            isFloating = true
        }
    }
}
