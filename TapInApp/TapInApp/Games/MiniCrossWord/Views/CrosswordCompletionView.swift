//
//  CrosswordCompletionView.swift
//  TapInApp
//
//  MARK: - View Layer
//  Overlay shown when puzzle is completed.
//

import SwiftUI

/// Completion overlay displayed when puzzle is solved
struct CrosswordCompletionView: View {
    let elapsedSeconds: Int
    let onDismiss: () -> Void
    let onBack: () -> Void
    let colorScheme: ColorScheme

    private var formattedTime: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            // Completion card
            VStack(spacing: 24) {
                // Trophy icon
                Image(systemName: "trophy.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Color.ucdGold)

                // Congratulations text
                VStack(spacing: 8) {
                    Text("Puzzle Complete!")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : Color.ucdBlue)

                    Text("Great job solving today's crossword!")
                        .font(.system(size: 16))
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }

                // Time display
                VStack(spacing: 4) {
                    Text("Your Time")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textSecondary)

                    Text(formattedTime)
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.ucdGold)
                }

                // Buttons
                VStack(spacing: 12) {
                    Button(action: onDismiss) {
                        Text("View Puzzle")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.ucdBlue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.ucdGold)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button(action: onBack) {
                        Text("Back to Games")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(colorScheme == .dark ? .white : Color.ucdBlue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.3) : Color.ucdBlue.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(colorScheme == .dark ? Color(hex: "#1a1a2e") : .white)
            )
            .padding(.horizontal, 32)
        }
    }
}

// MARK: - Preview
#Preview {
    CrosswordCompletionView(
        elapsedSeconds: 185,
        onDismiss: {},
        onBack: {},
        colorScheme: .light
    )
}
