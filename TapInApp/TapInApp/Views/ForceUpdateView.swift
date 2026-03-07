//
//  ForceUpdateView.swift
//  TapInApp
//
//  Non-dismissible full-screen overlay shown when the installed version
//  is behind the current App Store release.
//

import SwiftUI

struct ForceUpdateView: View {
    @Environment(\.colorScheme) var colorScheme

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
                .offset(x: -80, y: -160)

            VStack(spacing: 0) {
                Spacer()

                // App icon + title
                VStack(spacing: 20) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 72))
                        .foregroundColor(.white)
                        .shadow(color: .white.opacity(0.3), radius: 20)

                    VStack(spacing: 10) {
                        Text("Update Available")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)

                        Text("A new version of TapIn is ready.\nUpdate to keep playing and stay on the leaderboard.")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()

                // Update button
                Button(action: openAppStore) {
                    Text("Update Now")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? Color(hex: "#0d1b4b") : Color(hex: "#E8485A"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(.white, in: Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 52)
            }
        }
    }

    private func openAppStore() {
        guard let url = AppUpdateService.shared.appStoreURL else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    ForceUpdateView()
}
