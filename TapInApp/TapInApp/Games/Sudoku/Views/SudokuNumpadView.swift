//
//  SudokuNumpadView.swift
//  TapInApp
//
//  MARK: - View Layer (MVVM)
//  Number input pad for Sudoku.
//

import SwiftUI

/// Number pad for entering values in Sudoku cells.
struct SudokuNumpadView: View {
    let isNotesMode: Bool
    let onNumberTap: (Int) -> Void
    let onClearTap: () -> Void
    let onNotesTap: () -> Void
    let isDisabled: Bool

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 16) {
            // Numbers 1-9
            HStack(spacing: 8) {
                ForEach(1...9, id: \.self) { number in
                    numpadButton(number: number)
                }
            }

            // Action buttons
            HStack(spacing: 24) {
                // Clear button
                actionButton(
                    icon: "xmark.circle",
                    label: "Clear",
                    isActive: false,
                    action: onClearTap
                )

                Spacer()

                // Notes toggle
                actionButton(
                    icon: isNotesMode ? "pencil.circle.fill" : "pencil.circle",
                    label: "Notes",
                    isActive: isNotesMode,
                    action: onNotesTap
                )
            }
            .padding(.horizontal, 20)
        }
        .opacity(isDisabled ? 0.5 : 1.0)
        .disabled(isDisabled)
    }

    // MARK: - Numpad Button

    @ViewBuilder
    private func numpadButton(number: Int) -> some View {
        Button(action: { onNumberTap(number) }) {
            Text("\(number)")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundColor(colorScheme == .dark ? .white : Color.ucdBlue)
                .frame(width: 36, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(keyBackground)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Action Button

    @ViewBuilder
    private func actionButton(icon: String, label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                Text(label)
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(isActive ? Color.ucdGold : (colorScheme == .dark ? .white : Color.ucdBlue))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isActive ? Color.ucdGold.opacity(0.2) : keyBackground)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Colors

    private var keyBackground: Color {
        colorScheme == .dark ? Color(hex: "#2a2a3e") : Color(hex: "#f0f0f0")
    }
}
