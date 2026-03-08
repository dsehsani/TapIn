//
//  OnboardingView.swift
//  TapInApp
//
//  Root container — drives which onboarding screen is visible.
//

import SwiftUI

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            switch viewModel.currentStep {
            case .welcome:
                WelcomeView(viewModel: viewModel)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal:   .move(edge: .leading).combined(with: .opacity)
                    ))

            case .signInOptions:
                SignInOptionsView(viewModel: viewModel)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal:   .move(edge: .leading).combined(with: .opacity)
                    ))

            case .phoneEntry:
                PhoneEntryView(viewModel: viewModel)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal:   .move(edge: .leading).combined(with: .opacity)
                    ))

            case .otpVerification:
                OTPVerificationView(viewModel: viewModel)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal:   .move(edge: .leading).combined(with: .opacity)
                    ))

            case .profileSetup:
                ProfileSetupView(viewModel: viewModel)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal:   .move(edge: .leading).combined(with: .opacity)
                    ))

            case .interestsPicker:
                InterestsPickerView(viewModel: viewModel)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal:   .move(edge: .leading).combined(with: .opacity)
                    ))

            case .notificationPermissions:
                NotificationPermissionView(viewModel: viewModel)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal:   .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .animation(hasAppeared ? .easeInOut(duration: 0.35) : nil, value: viewModel.currentStep)
        .onAppear { hasAppeared = true }
    }
}

#Preview {
    OnboardingView()
}
