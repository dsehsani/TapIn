//
//  WelcomeView.swift
//  TapInApp
//
//  Screen 1 — Hero/splash.
//  Background pulls from the logo's gradient palette, staying on UC Davis brand colors.
//

import SwiftUI

struct WelcomeView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) var colorScheme

    // Dark logo gradient: deep navy → deep purple (matches dark_tapin_logo)
    private let darkGradient = LinearGradient(
        colors: [
            Color(hex: "#0d1b4b"), // deep navy (UC Davis navy family)
            Color(hex: "#1a1060"), // mid indigo
            Color(hex: "#2d0e52")  // deep purple (bottom of logo)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    // Light logo gradient: warm gold-orange → coral (matches light_tapin_logo)
    private let lightGradient = LinearGradient(
        colors: [
            Color(hex: "#F5A623"), // warm gold (UC Davis gold family)
            Color(hex: "#F06B3F"), // orange-coral
            Color(hex: "#E8485A")  // coral-pink
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        ZStack {
            // Background gradient matching the logo
            Group {
                if colorScheme == .dark {
                    darkGradient
                } else {
                    lightGradient
                }
            }
            .ignoresSafeArea()

            // Ambient glow behind the logo (mirrors the logo's inner glow)
            Color.white
                .opacity(0.08)
                .frame(width: 280, height: 280)
                .blur(radius: 80)
                .offset(y: -60)

            // Main layout
            VStack(spacing: 0) {
                Spacer()

                // --- Logo ---
                Image(colorScheme == .dark ? "TapInLogoDark" : "TapInLogoLight")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .shadow(color: .white.opacity(0.25), radius: 24, x: 0, y: 8)
                    .padding(.bottom, 48)

                // --- Hero Text ---
                VStack(spacing: 14) {
                    Text("Your Campus\nOne Place")
                        .font(.system(size: 36, weight: .heavy))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                        .padding(.horizontal, 28)

                    Text("Built for UC Davis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Spacer()

                // --- CTAs ---
                VStack(spacing: 20) {
                    // Primary button
                    Button(action: {
                        viewModel.navigateTo(.signInOptions)
                    }) {
                        Text("Get Started")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? Color(hex: "#0d1b4b") : Color(hex: "#E8485A"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(.white, in: Capsule())
                            .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)
                    }
                    .padding(.horizontal, 28)

                    // Secondary
                    Button(action: {
                        viewModel.navigateTo(.signInOptions)
                    }) {
                        Text("Already have an account? \(Text("Sign in").fontWeight(.bold).foregroundColor(.white))")
                            .foregroundColor(.white.opacity(0.65))
                    }
                    .font(.system(size: 14))
                }
                .padding(.bottom, 52)
            }
        }
    }
}

#Preview {
    WelcomeView(viewModel: OnboardingViewModel())
}
