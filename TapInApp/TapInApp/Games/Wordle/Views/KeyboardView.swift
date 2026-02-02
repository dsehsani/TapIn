//
//  KeyboardView.swift
//  WordleType
//
//  Created by Darius Ehsani on 1/20/26.
//
//  MARK: - View Layer (MVVM)
//  This view renders the on-screen QWERTY keyboard for letter input.
//  Keys change color to reflect letter states after guesses.
//
//  Integration Notes:
//  - Used by ContentView for player input
//  - Communicates with GameViewModel via callback closures
//  - Key colors reflect evaluated letter states (green/gold/gray)
//  - Disabled during animations or in read-only mode
//

import SwiftUI

// MARK: - Keyboard View
/// Renders the on-screen QWERTY keyboard for Wordle input.
///
/// Layout:
/// - Three rows in standard QWERTY arrangement
/// - ENTER key on the left of bottom row
/// - DELETE key on the right of bottom row
/// - Keys resize to fit screen width
///
/// Visual feedback:
/// - Keys turn green when letter is confirmed correct
/// - Keys turn gold when letter is in wrong position
/// - Keys turn gray when letter is not in word
///
struct KeyboardView: View {
    // MARK: - Callback Closures

    /// Called when a letter key is tapped
    /// - Parameter: The letter character (uppercase)
    let onKeyTap: (Character) -> Void

    /// Called when the delete key is tapped
    let onDelete: () -> Void

    /// Called when the enter key is tapped
    let onEnter: () -> Void

    /// Returns the current state for a given letter
    /// Used to determine key background color
    let getKeyState: (Character) -> LetterState

    /// Whether the keyboard is currently disabled
    /// True during reveal animations or in read-only mode
    let isDisabled: Bool

    /// Color scheme for dark mode support
    var colorScheme: ColorScheme = .light

    // MARK: - Keyboard Layout

    /// QWERTY keyboard layout with special keys
    private let rows: [[String]] = [
        ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
        ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
        ["ENTER", "Z", "X", "C", "V", "B", "N", "M", "DEL"]
    ]

    // MARK: - Body

    var body: some View {
        VStack(spacing: 6) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 5) {
                    ForEach(row, id: \.self) { key in
                        KeyView(
                            key: key,
                            state: key.count == 1 ? getKeyState(Character(key)) : .filled,
                            isDisabled: isDisabled,
                            colorScheme: colorScheme,
                            onTap: {
                                handleKeyTap(key)
                            }
                        )
                    }
                }
            }
        }
        // Dim keyboard when disabled
        .opacity(isDisabled ? 0.6 : 1.0)
    }

    // MARK: - Key Handling

    /// Routes key taps to appropriate callback
    private func handleKeyTap(_ key: String) {
        switch key {
        case "ENTER":
            onEnter()
        case "DEL":
            onDelete()
        default:
            onKeyTap(Character(key))
        }
    }
}

// MARK: - Key View
/// Renders a single keyboard key with state-based coloring.
///
/// Key types:
/// - Letter keys: Single character, state-colored
/// - ENTER key: Wide, submits current guess
/// - DEL key: Medium width, deletes last letter
///
struct KeyView: View {
    /// The key label (single letter or "ENTER"/"DEL")
    let key: String

    /// Current evaluation state of this letter
    /// Determines background color
    let state: LetterState

    /// Whether this key is currently disabled
    let isDisabled: Bool

    /// Color scheme for dark mode support
    var colorScheme: ColorScheme = .light

    /// Called when the key is tapped
    let onTap: () -> Void

    // MARK: - Computed Properties

    /// Whether this is a special key (ENTER or DEL)
    private var isSpecialKey: Bool {
        key == "ENTER" || key == "DEL"
    }

    /// Width of the key based on type
    private var keyWidth: CGFloat {
        switch key {
        case "ENTER": return 56
        case "DEL": return 50
        default: return 32
        }
    }

    /// Background color based on letter state (with dark mode support)
    private var backgroundColor: Color {
        switch state {
        case .correct:
            return .wordleGreen
        case .wrongPosition:
            return .ucdGold
        case .notInWord:
            return .wordleGray
        default:
            return Color.wordleKeyBackground(colorScheme)
        }
    }

    /// Text color (white on colored, adaptive otherwise)
    private var textColor: Color {
        switch state {
        case .correct, .wrongPosition, .notInWord:
            return .white
        default:
            return Color.wordleKeyText(colorScheme)
        }
    }

    // MARK: - Body

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(backgroundColor)

                // Delete key shows icon instead of text
                if key == "DEL" {
                    Image(systemName: "delete.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(textColor)
                } else {
                    Text(key)
                        .font(.system(size: isSpecialKey ? 11 : 15, weight: .semibold, design: .rounded))
                        .foregroundColor(textColor)
                }
            }
            .frame(width: keyWidth, height: 50)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
    }
}

// MARK: - Preview
#Preview {
    KeyboardView(
        onKeyTap: { _ in },
        onDelete: { },
        onEnter: { },
        getKeyState: { _ in .filled },
        isDisabled: false
    )
    .padding()
}
