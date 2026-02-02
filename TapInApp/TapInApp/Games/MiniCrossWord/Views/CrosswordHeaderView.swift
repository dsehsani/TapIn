//
//  CrosswordHeaderView.swift
//  TapInApp
//
//  MARK: - View Layer
//  Header with back button, timer, and menu.
//

import SwiftUI

/// Header view with navigation and game controls
struct CrosswordHeaderView: View {
    let formattedTime: String
    let onBack: () -> Void
    let onCheck: () -> Void
    let onRevealCell: () -> Void
    let onRevealWord: () -> Void
    let onRevealPuzzle: () -> Void
    let colorScheme: ColorScheme

    var body: some View {
        HStack {
            // Back button
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(Color.ucdBlue)
            }

            Spacer()

            // Timer
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 14))
                Text(formattedTime)
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
            }
            .foregroundColor(Color.crosswordText(colorScheme))

            Spacer()

            // Menu button
            Menu {
                Button(action: onCheck) {
                    Label("Check Puzzle", systemImage: "checkmark.circle")
                }
                Button(action: onRevealCell) {
                    Label("Reveal Letter", systemImage: "character")
                }
                Button(action: onRevealWord) {
                    Label("Reveal Word", systemImage: "text.word.spacing")
                }
                Button(action: onRevealPuzzle) {
                    Label("Reveal Puzzle", systemImage: "square.grid.3x3")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 22))
                    .foregroundColor(Color.ucdBlue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.crosswordHeaderBackground(colorScheme))
    }
}

// MARK: - Preview
#Preview {
    VStack {
        CrosswordHeaderView(
            formattedTime: "2:45",
            onBack: {},
            onCheck: {},
            onRevealCell: {},
            onRevealWord: {},
            onRevealPuzzle: {},
            colorScheme: .light
        )

        CrosswordHeaderView(
            formattedTime: "12:05",
            onBack: {},
            onCheck: {},
            onRevealCell: {},
            onRevealWord: {},
            onRevealPuzzle: {},
            colorScheme: .dark
        )
        .background(Color.black)
    }
}
