//
//  SudokuHeaderView.swift
//  TapInApp
//
//  MARK: - View Layer (MVVM)
//  Header view with navigation, timer, and difficulty.
//

import SwiftUI

/// Header view for Sudoku game with back button, title, timer, and difficulty.
struct SudokuHeaderView: View {
    let difficulty: SudokuDifficulty
    let formattedTime: String
    let onBack: () -> Void
    let onDifficultyTap: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 8) {
            // Top row: Back, Title, Timer
            HStack {
                // Back button
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(accentColor)
                }
                .frame(width: 44)

                Spacer()

                // Title
                Text("Aggie Sudoku")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(accentColor)

                Spacer()

                // Timer
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 14))
                    Text(formattedTime)
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                }
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Difficulty pill
            Button(action: onDifficultyTap) {
                HStack(spacing: 4) {
                    Text(difficulty.displayName)
                        .font(.system(size: 14, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(Color.ucdGold)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.ucdGold.opacity(0.2))
                )
            }
            .padding(.bottom, 8)
        }
        .background(headerBackground)
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 2, y: 2)
    }

    // MARK: - Colors

    private var accentColor: Color {
        colorScheme == .dark ? Color.ucdGold : Color.ucdBlue
    }

    private var headerBackground: Color {
        colorScheme == .dark ? Color(hex: "#1a1a2e") : .white
    }
}
