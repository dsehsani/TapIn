//
//  SequenceDisplayView.swift
//  TapInApp
//
//  MARK: - View Layer (MVVM)
//  Shows the original sequence for memorization during the showingSequence phase.
//  Includes staggered shape animations and a countdown progress bar.
//

import SwiftUI

// MARK: - Sequence Display View
struct SequenceDisplayView: View {
    let sequence: [EchoItem]
    let isVisible: Bool
    let countdownProgress: Double
    var colorScheme: ColorScheme = .light

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Instruction text
            Text("Memorize this sequence")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(colorScheme == .dark ? .white : Color.textPrimary)
                .opacity(isVisible ? 1 : 0)

            // Shape sequence
            HStack(spacing: 16) {
                ForEach(Array(sequence.enumerated()), id: \.element.id) { index, item in
                    ShapeItemView(item: item, size: 50)
                        .scaleEffect(isVisible ? 1.0 : 0.0)
                        .opacity(isVisible ? 1.0 : 0.0)
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.7)
                                .delay(Double(index) * 0.15),
                            value: isVisible
                        )
                }
            }

            // Countdown progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.textSecondary.opacity(0.2))
                        .frame(height: 6)

                    // Fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.ucdGold)
                        .frame(width: geometry.size.width * countdownProgress, height: 6)
                }
            }
            .frame(height: 6)
            .padding(.horizontal, 60)

            Text("Remember the shapes and colors!")
                .font(.system(size: 14))
                .foregroundColor(.textSecondary)
                .opacity(isVisible ? 1 : 0)

            Spacer()
        }
    }
}

#Preview {
    SequenceDisplayView(
        sequence: [
            EchoItem(shape: .triangle, color: .red),
            EchoItem(shape: .circle, color: .blue),
            EchoItem(shape: .square, color: .yellow),
            EchoItem(shape: .pentagon, color: .green)
        ],
        isVisible: true,
        countdownProgress: 0.7
    )
}
