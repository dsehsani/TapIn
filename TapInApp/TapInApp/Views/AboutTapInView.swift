//
//  AboutTapInView.swift
//  TapInApp
//
//  About sheet showing app info and team credits.
//

import SwiftUI

struct AboutTapInView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss

    private let team = [
        "Darius Ehsani",
        "Suhani Shokeen",
        "Jake Stelly",
        "Yash Pradhan",
        "James Fu"
    ]

    var body: some View {
        VStack(spacing: 20) {
            // Drag indicator
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            // App icon + name
            VStack(spacing: 8) {
                Image(colorScheme == .dark ? "TapInLogoDark" : "TapInLogoLight")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)

                Text("TapIn")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? .white : .primary)

                Text("v1.0.4")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }

            // Description
            Text("Your go-to app for UC Davis news, campus events, and games — all in one place.")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Team section
            VStack(spacing: 10) {
                Text("BUILT BY")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(.secondary)

                HStack(spacing: 6) {
                    ForEach(team, id: \.self) { name in
                        Text(name.components(separatedBy: " ").first ?? name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? .white : .primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                colorScheme == .dark
                                    ? Color.white.opacity(0.1)
                                    : Color.black.opacity(0.05)
                            )
                            .clipShape(Capsule())
                    }
                }

                Text("UC Davis \u{2022} ECS 191")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.adaptiveBackground(colorScheme))
    }
}

#Preview {
    AboutTapInView()
}
