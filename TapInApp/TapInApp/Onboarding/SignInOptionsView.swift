//
//  SignInOptionsView.swift
//  TapInApp
//
//  Screen 2 — Sign-in method picker.
//  Frosted glass button style consistent with the WelcomeView gradient palette.
//

import SwiftUI

struct SignInOptionsView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) var colorScheme

    // Same gradient palette as WelcomeView
    private let darkGradient = LinearGradient(
        colors: [
            Color(hex: "#0d1b4b"),
            Color(hex: "#1a1060"),
            Color(hex: "#2d0e52")
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    private let lightGradient = LinearGradient(
        colors: [
            Color(hex: "#F5A623"),
            Color(hex: "#F06B3F"),
            Color(hex: "#E8485A")
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        ZStack {
            // Same background as WelcomeView so the slide feels seamless
            Group {
                if colorScheme == .dark { darkGradient } else { lightGradient }
            }
            .ignoresSafeArea()

            // Ambient glow (same as welcome)
            Color.white
                .opacity(0.06)
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: 100, y: -200)

            VStack(alignment: .leading, spacing: 0) {

                // Back button
                Button(action: { viewModel.goBack() }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 42, height: 42)
                        .background(.white.opacity(0.15), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 40)

                // Title
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sign in to TapIn")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)

                    Text("Choose how you want to continue")
                        .font(.system(size: 17))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 44)

                // Auth buttons
                VStack(spacing: 14) {

                    // Google
                    GlassAuthButton(
                        action: { Task { await viewModel.signInWithGoogle() } }
                    ) {
                        HStack(spacing: 12) {
                            GoogleIcon()
                            Text("Continue with Google")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                    }

                    // Apple
                    GlassAuthButton(
                        action: { Task { await viewModel.signInWithApple() } }
                    ) {
                        HStack(spacing: 12) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                            Text("Continue with Apple")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                    }

                    // "or" divider
                    HStack(spacing: 12) {
                        Rectangle()
                            .fill(.white.opacity(0.2))
                            .frame(height: 1)
                        Text("or")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                            .textCase(.uppercase)
                            .tracking(2)
                        Rectangle()
                            .fill(.white.opacity(0.2))
                            .frame(height: 1)
                    }
                    .padding(.vertical, 4)

                    // Phone
                    GlassAuthButton(
                        action: { viewModel.navigateTo(.phoneEntry) }
                    ) {
                        HStack(spacing: 12) {
                            Image(systemName: "iphone")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                            Text("Continue with Phone")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // Privacy footer
                Text("By continuing, you agree to our \(Text("Terms").underline()) & \(Text("Privacy Policy").underline())")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 40)
                .padding(.bottom, 36)
            }
        }
    }
}

// MARK: - Frosted Glass Button

private struct GlassAuthButton<Content: View>: View {
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        Button(action: action) {
            content()
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(.white.opacity(0.12), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Google Logo (real SVG asset)

private struct GoogleIcon: View {
    var body: some View {
        Image("GoogleLogo")
            .resizable()
            .scaledToFit()
            .frame(width: 24, height: 24)
    }
}

// MARK: - Previews

#Preview("Dark") {
    SignInOptionsView(viewModel: OnboardingViewModel())
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    SignInOptionsView(viewModel: OnboardingViewModel())
        .preferredColorScheme(.light)
}
