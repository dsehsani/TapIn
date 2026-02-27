//
//  OTPVerificationView.swift
//  TapInApp
//
//  Screen 4 — 6-digit OTP entry.
//  UI only — verification logic wired in the dedicated phone auth prompt.
//

import SwiftUI
import Combine

struct OTPVerificationView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var isFieldFocused: Bool

    @State private var countdown: Int = 30
    @State private var canResend: Bool = false
    @State private var shakeOffset: CGFloat = 0
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private let darkGradient = LinearGradient(
        colors: [Color(hex: "#0d1b4b"), Color(hex: "#1a1060"), Color(hex: "#2d0e52")],
        startPoint: .top, endPoint: .bottom
    )
    private let lightGradient = LinearGradient(
        colors: [Color(hex: "#F5A623"), Color(hex: "#F06B3F"), Color(hex: "#E8485A")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    private var maskedPhone: String {
        let digits = viewModel.phoneNumber.filter(\.isNumber)
        guard digits.count >= 10 else { return viewModel.phoneNumber }
        let area = String(digits.prefix(3))
        let last4 = String(digits.suffix(4))
        return "+1 (\(area)) ••• \(last4)"
    }

    private var isComplete: Bool { viewModel.otpCode.count == 6 }

    var body: some View {
        ZStack {
            Group {
                if colorScheme == .dark { darkGradient } else { lightGradient }
            }
            .ignoresSafeArea()

            Color.white.opacity(0.06)
                .frame(width: 280, height: 280)
                .blur(radius: 80)
                .offset(x: 120, y: -200)

            VStack(alignment: .leading, spacing: 0) {

                // Back button
                Button(action: {
                    viewModel.otpCode = ""
                    viewModel.goBack()
                }) {
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
                    Text("Check your texts")
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundColor(.white)

                    Text("Enter the 6-digit code sent to \(Text(maskedPhone).foregroundColor(.white).fontWeight(.semibold))")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.system(size: 16))
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)

                // OTP digit boxes with native SwiftUI TextField for autofill
                ZStack {
                    // Digit boxes (visual layer)
                    HStack(spacing: 10) {
                        ForEach(0..<6, id: \.self) { index in
                            OTPDigitBox(
                                digit: digit(at: index),
                                isActive: index == viewModel.otpCode.count,
                                isFilled: index < viewModel.otpCode.count
                            )
                        }
                    }
                    .offset(x: shakeOffset)

                    // Native SwiftUI TextField — autofill works reliably
                    TextField("", text: $viewModel.otpCode)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .foregroundColor(.clear)
                        .tint(.clear)
                        .accentColor(.clear)
                        .focused($isFieldFocused)
                        .frame(maxWidth: .infinity)
                        .frame(height: 70)
                        .background(Color.clear)
                        .autocorrectionDisabled()
                        .onChange(of: viewModel.otpCode) { _, newValue in
                            let filtered = String(newValue.filter(\.isNumber).prefix(6))
                            if filtered != newValue {
                                viewModel.otpCode = filtered
                            }
                            if viewModel.errorMessage != nil {
                                viewModel.errorMessage = nil
                            }
                            if filtered.count == 6 {
                                Task { await viewModel.verifyOTP() }
                            }
                        }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 70)
                .padding(.horizontal, 24)

                // Error message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "#FF6B6B"))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 28)
                        .padding(.top, 16)
                        .transition(.opacity.animation(.easeInOut))
                }

                // Resend section
                VStack(spacing: 10) {
                    if canResend {
                        Button(action: {
                            viewModel.otpCode = ""
                            countdown = 30
                            canResend = false
                            Task { await viewModel.sendOTP() }
                        }) {
                            Text("Resend SMS")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    } else {
                        Text("Resend code in \(Text("0:\(String(format: "%02d", countdown))").foregroundColor(.white).fontWeight(.semibold))")
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .font(.system(size: 14))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, viewModel.errorMessage == nil ? 24 : 12)

                Spacer()

                // Verify button
                Button(action: {
                    guard isComplete else { shake(); return }
                    Task { await viewModel.verifyOTP() }
                }) {
                    ZStack {
                        Text("Verify")
                            .font(.system(size: 18, weight: .bold))
                            .opacity(viewModel.isLoading ? 0 : 1)

                        if viewModel.isLoading {
                            ProgressView()
                                .tint(colorScheme == .dark ? Color(hex: "#0d1b4b") : Color(hex: "#E8485A"))
                        }
                    }
                    .foregroundColor(isComplete
                        ? (colorScheme == .dark ? Color(hex: "#0d1b4b") : Color(hex: "#E8485A"))
                        : .white.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(isComplete ? .white : .white.opacity(0.15), in: Capsule())
                }
                .disabled(viewModel.isLoading)
                .animation(.easeInOut(duration: 0.2), value: isComplete)
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .onAppear { isFieldFocused = true }
        .onReceive(timer) { _ in
            if countdown > 0 {
                countdown -= 1
            } else {
                canResend = true
            }
        }
    }

    private func digit(at index: Int) -> String {
        guard index < viewModel.otpCode.count else { return "" }
        return String(viewModel.otpCode[viewModel.otpCode.index(viewModel.otpCode.startIndex, offsetBy: index)])
    }

    private func shake() {
        withAnimation(.easeInOut(duration: 0.05).repeatCount(5, autoreverses: true)) {
            shakeOffset = 8
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            shakeOffset = 0
        }
    }
}

// MARK: - OTP Digit Box

private struct OTPDigitBox: View {
    let digit: String
    let isActive: Bool
    let isFilled: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(isFilled ? 0.18 : 0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            isActive ? .white.opacity(0.9) : .white.opacity(isFilled ? 0.35 : 0.2),
                            lineWidth: isActive ? 2 : 1.5
                        )
                )

            if digit.isEmpty {
                Circle()
                    .fill(.white.opacity(isActive ? 0 : 0.3))
                    .frame(width: 8, height: 8)
            } else {
                Text(digit)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .animation(.easeInOut(duration: 0.15), value: isFilled)
        .animation(.easeInOut(duration: 0.15), value: isActive)
    }
}

#Preview("Dark") {
    OTPVerificationView(viewModel: OnboardingViewModel())
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    OTPVerificationView(viewModel: OnboardingViewModel())
        .preferredColorScheme(.light)
}
