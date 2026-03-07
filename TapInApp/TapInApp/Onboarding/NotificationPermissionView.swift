//
//  NotificationPermissionView.swift
//  TapInApp
//
//  Last onboarding step — lets users choose which notification types they want
//  before triggering the iOS system permission dialog.
//

import SwiftUI

struct NotificationPermissionView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) var colorScheme

    @State private var eventsOn: Bool = true
    @State private var gamesOn: Bool = true
    @State private var isRequesting: Bool = false

    private let darkGradient = LinearGradient(
        colors: [Color(hex: "#0d1b4b"), Color(hex: "#1a1060"), Color(hex: "#2d0e52")],
        startPoint: .top, endPoint: .bottom
    )
    private let lightGradient = LinearGradient(
        colors: [Color(hex: "#F5A623"), Color(hex: "#F06B3F"), Color(hex: "#E8485A")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    var body: some View {
        ZStack {
            Group {
                if colorScheme == .dark { darkGradient } else { lightGradient }
            }
            .ignoresSafeArea()

            Color.white.opacity(0.06)
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: 80, y: -160)

            VStack(spacing: 0) {
                headerBar
                Spacer()
                titleSection
                    .padding(.bottom, 40)
                togglesSection
                    .padding(.horizontal, 24)
                Spacer()
                ctaSection
                    .padding(.horizontal, 24)
                    .padding(.bottom, 52)
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Button(action: { viewModel.goBack() }) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.15), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 20)
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 52))
                .foregroundColor(.white)
                .shadow(color: .white.opacity(0.3), radius: 16)

            Text("Stay in the Loop")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)

            Text("We only send what matters.\nNo spam, ever.")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.65))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Toggles

    private var togglesSection: some View {
        VStack(spacing: 14) {
            notificationRow(
                icon: "calendar.badge.clock",
                title: "Campus Events",
                subtitle: "Reminders for events you save",
                isOn: $eventsOn
            )
            notificationRow(
                icon: "gamecontroller.fill",
                title: "Game Reminders",
                subtitle: "Daily nudge to complete DailyFive",
                isOn: $gamesOn
            )
        }
    }

    private func notificationRow(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color.white.opacity(0.9))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - CTA

    private var ctaSection: some View {
        VStack(spacing: 16) {
            Button(action: { Task { await allowAndFinish() } }) {
                Group {
                    if isRequesting {
                        ProgressView().tint(colorScheme == .dark ? Color(hex: "#0d1b4b") : Color(hex: "#E8485A"))
                    } else {
                        Text(eventsOn || gamesOn ? "Allow Notifications" : "Continue")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? Color(hex: "#0d1b4b") : Color(hex: "#E8485A"))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(.white, in: Capsule())
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
            }
            .disabled(isRequesting)

            Button(action: { Task { await skipAndFinish() } }) {
                Text("Not now")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                    .padding(.vertical, 8)
            }
            .disabled(isRequesting)
        }
    }

    // MARK: - Actions

    private func allowAndFinish() async {
        isRequesting = true
        AppState.shared.eventNotificationsEnabled = eventsOn
        AppState.shared.gameNotificationsEnabled = gamesOn

        if eventsOn || gamesOn {
            // Request iOS permission — user has already told us what they want
            _ = await NotificationService.shared.requestPermissionIfNeeded()
        }

        if gamesOn {
            await NotificationService.shared.scheduleDailyFiveReminders()
        }

        await viewModel.completeOnboarding()
    }

    private func skipAndFinish() async {
        AppState.shared.eventNotificationsEnabled = false
        AppState.shared.gameNotificationsEnabled = false
        await viewModel.completeOnboarding()
    }
}

#Preview {
    NotificationPermissionView(viewModel: OnboardingViewModel())
}
