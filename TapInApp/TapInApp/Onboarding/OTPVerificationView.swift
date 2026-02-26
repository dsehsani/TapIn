//
//  OTPVerificationView.swift
//  TapInApp
//
//  Screen 4 — 6-digit OTP entry.
//  UI only — verification logic wired in the dedicated phone auth prompt.
//

import SwiftUI
import Combine
import UIKit

// MARK: - UIKit OTP TextField (reliable autofill)

struct AutofillOTPField: UIViewRepresentable {
    @Binding var text: String
    var onComplete: (() -> Void)?

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.textContentType = .oneTimeCode
        field.keyboardType = .numberPad
        field.autocorrectionType = .no
        field.textColor = .clear
        field.tintColor = .clear
        field.backgroundColor = .clear
        field.font = .systemFont(ofSize: 24)
        field.textAlignment = .center
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        // Auto-focus
        if !uiView.isFirstResponder {
            DispatchQueue.main.async { uiView.becomeFirstResponder() }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: AutofillOTPField

        init(_ parent: AutofillOTPField) {
            self.parent = parent
        }

        @objc func textChanged(_ textField: UITextField) {
            let filtered = String((textField.text ?? "").filter(\.isNumber).prefix(6))
            parent.text = filtered
            textField.text = filtered
            if filtered.count == 6 {
                parent.onComplete?()
            }
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let current = textField.text ?? ""
            guard let range = Range(range, in: current) else { return false }
            let updated = current.replacingCharacters(in: range, with: string)
            let filtered = String(updated.filter(\.isNumber).prefix(6))
            return filtered.count <= 6
        }
    }
}

struct OTPVerificationView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) var colorScheme

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

                // OTP digit boxes + UIKit autofill TextField
                ZStack {
                    // Digit boxes (visual layer behind)
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

                    // UIKit TextField on top — handles autofill reliably
                    AutofillOTPField(text: $viewModel.otpCode) {
                        Task { await viewModel.verifyOTP() }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onChange(of: viewModel.otpCode) { _, _ in
                        if viewModel.errorMessage != nil { viewModel.errorMessage = nil }
                    }
                }
                .frame(maxWidth: .infinity)
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
