//
//  AISummaryBadge.swift
//  TapInApp
//
//  Created by Darius Ehsani on 2/12/26.
//
//  MARK: - AI Summary Badge Component
//  Displays an AI-generated summary with an animated rainbow gradient border,
//  inspired by Apple Intelligence / Google Gemini aesthetics.
//

import SwiftUI

struct AISummaryBadge: View {
    let summary: String
    @Environment(\.colorScheme) var colorScheme

    // Animation state
    @State private var rotation: Double = 0
    @State private var glowOpacity: Double = 0.4

    // Rainbow gradient colors (Blue → Purple → Gold → Pink)
    private let gradientColors: [Color] = [
        Color(hex: "#3b82f6"),  // Blue
        Color(hex: "#8b5cf6"),  // Purple
        Color(hex: "#FFBF00"),  // UC Davis Gold
        Color(hex: "#ec4899"),  // Pink
        Color(hex: "#3b82f6")   // Blue (loop)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Summary text
            Text(summary)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.9) : Color(hex: "#334155"))
                .lineLimit(2)
                .lineSpacing(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(hex: "#1a1a2e").opacity(0.8) : Color(hex: "#faf5ff").opacity(0.9))
        )
        // Animated rotating gradient border
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    AngularGradient(
                        colors: gradientColors,
                        center: .center,
                        angle: .degrees(rotation)
                    ),
                    lineWidth: 1.5
                )
        )
        // Subtle breathing glow behind the badge
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    AngularGradient(
                        colors: gradientColors,
                        center: .center,
                        angle: .degrees(rotation + 90)
                    )
                )
                .blur(radius: 8)
                .opacity(glowOpacity)
                .scaleEffect(1.02)
        )
        .onAppear {
            // Slow continuous rotation (one full turn every 6 seconds)
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            // Gentle breathing pulse on the glow
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                glowOpacity = 0.15
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        AISummaryBadge(summary: "Connect with top Bay Area employers at this career fair featuring tech, biotech, and finance companies.")

        AISummaryBadge(summary: "Weekly study session for ECS 170 students to practice AI algorithms and prep for the midterm.")
    }
    .padding()
}
