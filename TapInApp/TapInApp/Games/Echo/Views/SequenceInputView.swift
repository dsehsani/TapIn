//
//  SequenceInputView.swift
//  TapInApp
//
//  MARK: - View Layer (MVVM)
//  Player input screen where the user builds their answer sequence.
//  Includes rule reminder pills, answer slots, shape picker, and action buttons.
//

import SwiftUI

// MARK: - Sequence Input View
struct SequenceInputView: View {
    let rules: [EchoRule]
    let playerSequence: [EchoItem]
    let onShapeSelected: (EchoShape) -> Void
    let onCycleColor: (Int) -> Void
    let onRemoveItem: (Int) -> Void
    let onClear: () -> Void
    let onSubmit: () -> Void
    var colorScheme: ColorScheme = .light

    var body: some View {
        VStack(spacing: 20) {
            // Instruction
            Text("Build your answer")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(colorScheme == .dark ? .white : Color.textPrimary)

            // Rule reminder pills
            RulePillsView(rules: rules, colorScheme: colorScheme)

            Spacer()

            // Answer slots area
            AnswerSlotsView(
                playerSequence: playerSequence,
                onCycleColor: onCycleColor,
                onRemoveItem: onRemoveItem,
                colorScheme: colorScheme
            )

            Spacer()

            // Shape picker
            ShapePicker(onShapeSelected: onShapeSelected, colorScheme: colorScheme)

            // Action buttons
            HStack(spacing: 16) {
                // Clear button
                Button(action: onClear) {
                    Text("Clear")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .white : Color.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#f1f5f9"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(playerSequence.isEmpty)
                .opacity(playerSequence.isEmpty ? 0.4 : 1.0)

                // Submit button
                Button(action: onSubmit) {
                    Text("Submit")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(playerSequence.isEmpty ? Color.ucdBlue.opacity(0.4) : Color.ucdBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(playerSequence.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Rule Reminder Pills
struct RulePillsView: View {
    let rules: [EchoRule]
    var colorScheme: ColorScheme = .light

    var body: some View {
        HStack(spacing: 8) {
            Text("Rules:")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.textSecondary)

            ForEach(Array(rules.enumerated()), id: \.offset) { index, rule in
                HStack(spacing: 4) {
                    Text("\(index + 1).")
                        .font(.system(size: 12, weight: .bold))
                    Text(rule.displayName)
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(Color.ucdBlue)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.ucdGold.opacity(0.2))
                .clipShape(Capsule())
            }
        }
    }
}

// MARK: - Answer Slots
struct AnswerSlotsView: View {
    let playerSequence: [EchoItem]
    let onCycleColor: (Int) -> Void
    let onRemoveItem: (Int) -> Void
    var colorScheme: ColorScheme = .light

    var body: some View {
        VStack(spacing: 12) {
            if playerSequence.isEmpty {
                // Empty state placeholder
                VStack(spacing: 8) {
                    Image(systemName: "plus.circle.dashed")
                        .font(.system(size: 40))
                        .foregroundColor(.textSecondary.opacity(0.5))
                    Text("Tap a shape below to begin")
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)
                }
                .frame(height: 100)
            } else {
                // Player's sequence
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(playerSequence.enumerated()), id: \.element.id) { index, item in
                            ShapeItemView(item: item, size: 50)
                                .onTapGesture {
                                    onCycleColor(index)
                                }
                                .onLongPressGesture {
                                    onRemoveItem(index)
                                }
                                .transition(.scale.combined(with: .opacity))
                        }

                        // Plus indicator
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                                .foregroundColor(.textSecondary.opacity(0.3))
                                .frame(width: 66, height: 66)
                            Image(systemName: "plus")
                                .font(.system(size: 20))
                                .foregroundColor(.textSecondary.opacity(0.4))
                        }
                    }
                    .padding(.horizontal, 24)
                }

                // Hint text
                Text("Tap shape to cycle color \u{2022} Long press to remove")
                    .font(.system(size: 11))
                    .foregroundColor(.textSecondary)
            }
        }
        .frame(minHeight: 100)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "#0f172a").opacity(0.5) : Color(hex: "#f8fafc"))
        )
        .padding(.horizontal, 16)
    }
}

// MARK: - Shape Picker
struct ShapePicker: View {
    let onShapeSelected: (EchoShape) -> Void
    var colorScheme: ColorScheme = .light

    var body: some View {
        HStack(spacing: 12) {
            ForEach(EchoShape.allCases, id: \.self) { shape in
                Button(action: { onShapeSelected(shape) }) {
                    VStack(spacing: 6) {
                        Image(systemName: shape.symbolName)
                            .font(.system(size: 28))
                            .foregroundColor(Color.ucdBlue)
                        Text(shape.displayName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(colorScheme == .dark ? Color(hex: "#0f172a") : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#e2e8f0"), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
    }
}

#Preview {
    SequenceInputView(
        rules: [.reversed, .colorSwapped],
        playerSequence: [
            EchoItem(shape: .triangle, color: .red),
            EchoItem(shape: .circle, color: .blue)
        ],
        onShapeSelected: { _ in },
        onCycleColor: { _ in },
        onRemoveItem: { _ in },
        onClear: {},
        onSubmit: {}
    )
    .background(Color.adaptiveBackground(.light))
}
