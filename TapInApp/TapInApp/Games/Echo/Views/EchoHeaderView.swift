//
//  EchoHeaderView.swift
//  TapInApp
//
//  MARK: - View Layer (MVVM)
//  Top navigation bar for the Echo game showing back button,
//  round indicator, and attempt dots.
//

import SwiftUI

// MARK: - Echo Header View
struct EchoHeaderView: View {
    let onBack: () -> Void
    let roundIndex: Int
    let totalRounds: Int
    let attemptsRemaining: Int
    let maxAttempts: Int
    let showAttempts: Bool
    var colorScheme: ColorScheme = .light

    private var accentColor: Color {
        Color.adaptiveAccent(colorScheme)
    }

    var body: some View {
        HStack {
            // Back button
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(accentColor)
            }

            Spacer()

            // Round indicator
            Text("Round \(roundIndex + 1)/\(totalRounds)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(colorScheme == .dark ? .white : Color.textPrimary)

            Spacer()

            // Attempt dots
            if showAttempts {
                HStack(spacing: 6) {
                    ForEach(0..<maxAttempts, id: \.self) { index in
                        Circle()
                            .fill(index < attemptsRemaining ? accentColor : Color.textSecondary.opacity(0.3))
                            .frame(width: 10, height: 10)
                    }
                }
            } else {
                // Invisible placeholder to keep layout symmetric
                HStack(spacing: 6) {
                    ForEach(0..<maxAttempts, id: \.self) { _ in
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 10, height: 10)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.adaptiveCardBackground(colorScheme))
    }
}

#Preview {
    VStack {
        EchoHeaderView(
            onBack: {},
            roundIndex: 2,
            totalRounds: 5,
            attemptsRemaining: 2,
            maxAttempts: 3,
            showAttempts: true,
            colorScheme: .light
        )
        EchoHeaderView(
            onBack: {},
            roundIndex: 0,
            totalRounds: 5,
            attemptsRemaining: 3,
            maxAttempts: 3,
            showAttempts: false,
            colorScheme: .dark
        )
    }
}
