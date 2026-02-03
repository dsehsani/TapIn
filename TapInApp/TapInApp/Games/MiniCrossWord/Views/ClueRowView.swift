//
//  ClueRowView.swift
//  TapInApp
//
//  MARK: - View Layer
//  Single clue row display.
//

import SwiftUI

/// Displays a single clue in the clue list
struct ClueRowView: View {
    let clue: CrosswordClue
    let isSelected: Bool
    let colorScheme: ColorScheme
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 8) {
                Text("\(clue.number).")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(isSelected ? Color.ucdGold : Color.crosswordClueNumber(colorScheme))
                    .frame(width: 24, alignment: .trailing)

                Text(clue.text)
                    .font(.system(size: 13))
                    .foregroundColor(Color.crosswordText(colorScheme))
                    .multilineTextAlignment(.leading)

                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.crosswordHighlighted(colorScheme) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
#Preview {
    VStack {
        ClueRowView(
            clue: CrosswordClue(number: 1, direction: .across, text: "UC Davis mascot", answer: "AGGIE", startRow: 0, startCol: 0),
            isSelected: true,
            colorScheme: .light,
            onTap: {}
        )
        ClueRowView(
            clue: CrosswordClue(number: 2, direction: .across, text: "Campus bike path", answer: "TRAIL", startRow: 1, startCol: 0),
            isSelected: false,
            colorScheme: .light,
            onTap: {}
        )
    }
    .padding()
}
