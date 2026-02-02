//
//  CrosswordKeyboardView.swift
//  TapInApp
//
//  MARK: - View Layer
//  QWERTY keyboard for crossword input.
//

import SwiftUI

/// On-screen keyboard for crossword input
struct CrosswordKeyboardView: View {
    let onKeyTap: (Character) -> Void
    let onDelete: () -> Void
    let isDisabled: Bool
    let colorScheme: ColorScheme

    private let rows: [[String]] = [
        ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
        ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
        ["Z", "X", "C", "V", "B", "N", "M", "DEL"]
    ]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 5) {
                    ForEach(row, id: \.self) { key in
                        CrosswordKeyView(
                            key: key,
                            colorScheme: colorScheme,
                            onTap: {
                                if key == "DEL" {
                                    onDelete()
                                } else {
                                    onKeyTap(Character(key))
                                }
                            }
                        )
                    }
                }
            }
        }
        .opacity(isDisabled ? 0.6 : 1.0)
        .disabled(isDisabled)
    }
}

/// Single keyboard key
struct CrosswordKeyView: View {
    let key: String
    let colorScheme: ColorScheme
    let onTap: () -> Void

    private var keyWidth: CGFloat {
        key == "DEL" ? 50 : 32
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.crosswordKeyBackground(colorScheme))

                if key == "DEL" {
                    Image(systemName: "delete.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color.crosswordKeyText(colorScheme))
                } else {
                    Text(key)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.crosswordKeyText(colorScheme))
                }
            }
            .frame(width: keyWidth, height: 50)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
#Preview {
    CrosswordKeyboardView(
        onKeyTap: { _ in },
        onDelete: {},
        isDisabled: false,
        colorScheme: .light
    )
    .padding()
}
