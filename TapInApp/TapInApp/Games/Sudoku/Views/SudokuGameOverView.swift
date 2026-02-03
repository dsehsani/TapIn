//
//  SudokuGameOverView.swift
//  TapInApp
//
//  MARK: - View Layer (MVVM)
//  Game completion overlay with stats.
//

import SwiftUI

/// Overlay shown when the Sudoku puzzle is completed.
struct SudokuGameOverView: View {
    let elapsedTime: String
    let difficulty: SudokuDifficulty
    let errorCount: Int
    let onChangeDifficulty: () -> Void
    let onDismiss: () -> Void
    let onBack: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(colorScheme == .dark ? 0.6 : 0.4)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            // Card
            VStack(spacing: 24) {
                // Trophy icon
                Image(systemName: "trophy.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Color.ucdGold)

                Text("Puzzle Complete!")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(accentColor)

                // Stats
                VStack(spacing: 14) {
                    statRow(icon: "clock", label: "Time", value: elapsedTime)
                    statRow(icon: "chart.bar", label: "Difficulty", value: difficulty.displayName)
                    statRow(icon: "xmark.circle", label: "Errors", value: "\(errorCount)")
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.1))
                )

                // Message
                Text("Come back tomorrow for a new puzzle!")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                // Actions
                VStack(spacing: 12) {
                    Button(action: onChangeDifficulty) {
                        Text("Try Different Difficulty")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(accentColor)
                            .cornerRadius(25)
                    }

                    Button(action: onBack) {
                        Text("Back to Games")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(accentColor)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(cardBackground)
                    .shadow(color: .black.opacity(0.2), radius: 20)
            )
            .padding(32)
        }
    }

    // MARK: - Stat Row

    @ViewBuilder
    private func statRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.secondary)
                .frame(width: 24)

            Text(label)
                .font(.system(size: 16))
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(colorScheme == .dark ? .white : .primary)
        }
    }

    // MARK: - Colors

    private var accentColor: Color {
        colorScheme == .dark ? Color.ucdGold : Color.ucdBlue
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "#1a1a2e") : .white
    }
}
