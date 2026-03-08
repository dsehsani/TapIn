//
//  SplashView.swift
//  TapInApp
//
//  Branded splash screen shown while the app validates the session
//  and checks for updates on cold launch.
//

import SwiftUI

struct SplashView: View {
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

            Color.white
                .opacity(0.08)
                .frame(width: 280, height: 280)
                .blur(radius: 80)
                .offset(y: -60)

            VStack(spacing: 0) {
                Spacer()

                Image(colorScheme == .dark ? "TapInLogoDark" : "TapInLogoLight")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .shadow(color: .white.opacity(0.25), radius: 24, x: 0, y: 8)

                Spacer()

                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.1)
                    .padding(.bottom, 64)
            }
        }
        .transition(.opacity)
    }
}

#Preview {
    SplashView()
}
