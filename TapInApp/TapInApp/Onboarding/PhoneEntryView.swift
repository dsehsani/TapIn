//
//  PhoneEntryView.swift
//  TapInApp
//
//  Screen 3 — Phone number entry.
//  UI only — SMS logic wired in the dedicated phone auth prompt.
//

import SwiftUI

struct PhoneEntryView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var isPhoneFocused: Bool

    // Same gradients as WelcomeView / SignInOptionsView
    private let darkGradient = LinearGradient(
        colors: [Color(hex: "#0d1b4b"), Color(hex: "#1a1060"), Color(hex: "#2d0e52")],
        startPoint: .top, endPoint: .bottom
    )
    private let lightGradient = LinearGradient(
        colors: [Color(hex: "#F5A623"), Color(hex: "#F06B3F"), Color(hex: "#E8485A")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    private var isValidNumber: Bool {
        viewModel.phoneNumber.filter(\.isNumber).count >= 10
    }

    var body: some View {
        ZStack {
            Group {
                if colorScheme == .dark { darkGradient } else { lightGradient }
            }
            .ignoresSafeArea()

            // Ambient glow
            Color.white.opacity(0.06)
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: -100, y: -180)

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
                    Text("Enter your number")
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundColor(.white)

                    Text("We'll send you a verification code")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 36)

                // Phone input field
                HStack(spacing: 0) {
                    // Country selector (US only for now)
                    HStack(spacing: 6) {
                        Text("🇺🇸")
                            .font(.system(size: 22))
                        Text("+1")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 14)

                    // Vertical divider
                    Rectangle()
                        .fill(.white.opacity(0.25))
                        .frame(width: 1, height: 36)

                    // Phone number text field
                    TextField("000 000 0000", text: $viewModel.phoneNumber)
                        .keyboardType(.phonePad)
                        .focused($isPhoneFocused)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .tint(.white)
                        .placeholder(when: viewModel.phoneNumber.isEmpty) {
                            Text("000 000 0000")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white.opacity(0.35))
                        }
                        .padding(.horizontal, 14)
                        .onChange(of: viewModel.phoneNumber) { _, newVal in
                            viewModel.phoneNumber = formatPhone(newVal)
                            if viewModel.errorMessage != nil { viewModel.errorMessage = nil }
                        }
                }
                .frame(height: 72)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(isPhoneFocused ? .white.opacity(0.6) : .white.opacity(0.2), lineWidth: 1.5)
                )
                .animation(.easeInOut(duration: 0.2), value: isPhoneFocused)
                .padding(.horizontal, 24)
                .onTapGesture { isPhoneFocused = true }

                // Error message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "#FF6B6B"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                        .padding(.top, 14)
                        .transition(.opacity.animation(.easeInOut))
                }

                // SMS disclaimer
                Text("Standard SMS rates may apply")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.45))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, viewModel.errorMessage == nil ? 14 : 8)

                Spacer()

                // Subtle TapIn branding
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.white.opacity(0.3))
                        .frame(width: 22, height: 22)
                        .overlay(
                            Text("T")
                                .font(.system(size: 12, weight: .black))
                                .foregroundColor(.white)
                        )
                    Text("TAPIN")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(3)
                        .foregroundColor(.white.opacity(0.3))
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 20)

                // Send Code button
                Button(action: {
                    isPhoneFocused = false
                    Task { await viewModel.sendOTP() }
                }) {
                    ZStack {
                        Text("Send Code")
                            .font(.system(size: 18, weight: .bold))
                            .opacity(viewModel.isLoading ? 0 : 1)

                        if viewModel.isLoading {
                            ProgressView()
                                .tint(colorScheme == .dark ? Color(hex: "#0d1b4b") : Color(hex: "#E8485A"))
                        }
                    }
                    .foregroundColor(isValidNumber
                        ? (colorScheme == .dark ? Color(hex: "#0d1b4b") : Color(hex: "#E8485A"))
                        : .white.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(
                        isValidNumber ? .white : .white.opacity(0.15),
                        in: Capsule()
                    )
                }
                .disabled(!isValidNumber || viewModel.isLoading)
                .animation(.easeInOut(duration: 0.2), value: isValidNumber)
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .onAppear { isPhoneFocused = true }
    }

    // Format as US phone: "000 000 0000"
    private func formatPhone(_ raw: String) -> String {
        let digits = raw.filter(\.isNumber)
        let capped  = String(digits.prefix(10))
        var result  = ""
        for (i, ch) in capped.enumerated() {
            if i == 3 || i == 6 { result += " " }
            result.append(ch)
        }
        return result
    }
}

// MARK: - Placeholder helper

extension View {
    func placeholder<Content: View>(
        when condition: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack(alignment: .leading) {
            if condition { content() }
            self
        }
    }
}

#Preview("Dark") {
    PhoneEntryView(viewModel: OnboardingViewModel())
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    PhoneEntryView(viewModel: OnboardingViewModel())
        .preferredColorScheme(.light)
}
