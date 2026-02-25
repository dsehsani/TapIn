//
//  OnboardingTipView.swift
//  TapInApp
//
//  MARK: - Frosted Glass Tooltip
//  Contextual tooltip with a triangle arrow, frosted glass background,
//  and scale+opacity entrance animation.
//

import SwiftUI

struct OnboardingTipView: View {
    let message: String
    let arrowEdge: Edge  // .top = arrow points up (tooltip below target)

    var body: some View {
        VStack(spacing: 0) {
            if arrowEdge == .top {
                triangle(pointingUp: true)
            }

            Text(message)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                )

            if arrowEdge == .bottom {
                triangle(pointingUp: false)
            }
        }
    }

    private func triangle(pointingUp: Bool) -> some View {
        Triangle()
            .fill(.ultraThinMaterial)
            .environment(\.colorScheme, .dark)
            .frame(width: 16, height: 8)
            .rotationEffect(.degrees(pointingUp ? 0 : 180))
    }
}

// MARK: - Triangle Shape

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    ZStack {
        Color.black.opacity(0.3).ignoresSafeArea()
        VStack(spacing: 40) {
            OnboardingTipView(message: "Get the tea. Your daily AI breakdown.", arrowEdge: .top)
            OnboardingTipView(message: "Don't be a stranger. Set your year & major.", arrowEdge: .bottom)
        }
    }
}
