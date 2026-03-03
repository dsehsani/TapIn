//
//  InterestsPickerView.swift
//  TapInApp
//
//  Interests picker — Multi-select chip grid for choosing news interests.
//  Appears before ProfileSetupView. "Continue" and "Skip" both navigate to profile setup.
//

import SwiftUI

struct InterestsPickerView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) var colorScheme

    private let darkGradient = LinearGradient(
        colors: [Color(hex: "#0d1b4b"), Color(hex: "#1a1060"), Color(hex: "#2d0e52")],
        startPoint: .top, endPoint: .bottom
    )
    private let lightGradient = LinearGradient(
        colors: [Color(hex: "#F5A623"), Color(hex: "#F06B3F"), Color(hex: "#E8485A")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    var body: some View {
        ZStack {
            Group {
                if colorScheme == .dark { darkGradient } else { lightGradient }
            }
            .ignoresSafeArea()

            // Ambient glow
            Color.white.opacity(0.06)
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: -80, y: -160)

            VStack(spacing: 0) {
                headerBar
                Spacer()
                titleSection
                    .padding(.bottom, 32)
                chipsSection
                    .padding(.horizontal, 24)
                Spacer()
                ctaSection
                    .padding(.horizontal, 24)
                    .padding(.bottom, 52)
            }
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            Button(action: { viewModel.goBack() }) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.15), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 20)
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(spacing: 8) {
            Text("What are you into?")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)

            Text("Pick topics you care about.\nWe'll personalize your daily briefing.")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.65))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Chips Grid

    private var chipsSection: some View {
        InterestsFlowLayout(spacing: 10) {
            ForEach(OnboardingViewModel.availableInterests, id: \.self) { interest in
                let isSelected = viewModel.selectedInterests.contains(interest)

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        if isSelected {
                            viewModel.selectedInterests.remove(interest)
                        } else {
                            viewModel.selectedInterests.insert(interest)
                        }
                    }
                }) {
                    Text(interest)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(isSelected ? 1 : 0.6))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(
                            .white.opacity(isSelected ? 0.25 : 0.10),
                            in: Capsule()
                        )
                        .overlay(
                            Capsule().stroke(
                                .white.opacity(isSelected ? 0.6 : 0.2),
                                lineWidth: isSelected ? 1.5 : 1
                            )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - CTA Section

    private var ctaSection: some View {
        VStack(spacing: 16) {
            Button(action: { viewModel.navigateTo(.profileSetup) }) {
                Text("Continue")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? Color(hex: "#0d1b4b") : Color(hex: "#E8485A"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(.white, in: Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
            }

            Button(action: {
                viewModel.selectedInterests = []
                viewModel.navigateTo(.profileSetup)
            }) {
                Text("Skip for now")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                    .padding(.vertical, 8)
            }
        }
    }
}

// MARK: - Flow Layout (wrapping HStack)

struct InterestsFlowLayout: Layout {
    var spacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineH: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += lineH + spacing
                lineH = 0
            }
            x += size.width + spacing
            lineH = max(lineH, size.height)
        }
        return CGSize(width: maxWidth, height: y + lineH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        // First pass: group subviews into rows
        var rows: [[LayoutSubviews.Element]] = [[]]
        var rowWidths: [CGFloat] = [0]
        var rowHeights: [CGFloat] = [0]

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let currentRowWidth = rowWidths[rows.count - 1]
            let additionalWidth = rows[rows.count - 1].isEmpty ? size.width : spacing + size.width

            if currentRowWidth + additionalWidth > bounds.width, !rows[rows.count - 1].isEmpty {
                rows.append([subview])
                rowWidths.append(size.width)
                rowHeights.append(size.height)
            } else {
                rows[rows.count - 1].append(subview)
                rowWidths[rows.count - 1] += (rows[rows.count - 1].count == 1 ? 0 : spacing) + size.width
                rowHeights[rows.count - 1] = max(rowHeights[rows.count - 1], size.height)
            }
        }

        // Second pass: place each row centered
        var y = bounds.minY
        for (index, row) in rows.enumerated() {
            let rowWidth = rowWidths[index]
            var x = bounds.minX + (bounds.width - rowWidth) / 2

            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeights[index] + spacing
        }
    }
}

// MARK: - Previews

#Preview("Dark") {
    InterestsPickerView(viewModel: OnboardingViewModel())
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    InterestsPickerView(viewModel: OnboardingViewModel())
        .preferredColorScheme(.light)
}
