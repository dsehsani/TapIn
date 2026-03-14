//
//  SuggestedLocationBadge.swift
//  TapInApp
//
//  Tappable warning icon for location confidence. Shows a styled confidence meter popover.
//

import SwiftUI

struct SuggestedLocationBadge: View {
    let confidence: Int
    let reason: String

    @Environment(\.colorScheme) var colorScheme
    @State private var showingInfo = false

    private var level: LocationConfidenceLevel {
        if confidence >= 80 { return .high }
        if confidence >= 50 { return .moderate }
        if confidence > 0   { return .low }
        return .none
    }

    var body: some View {
        Button {
            showingInfo = true
        } label: {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundColor(level.color)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingInfo) {
            VStack(spacing: 10) {
                // Confidence label
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(level.color)
                    Text(level.label)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#e2e8f0"))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(level.color)
                            .frame(width: geo.size.width * CGFloat(confidence) / 100, height: 8)
                    }
                }
                .frame(height: 8)

                // Reason text
                Text(reason)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : Color(hex: "#64748b"))
                    .multilineTextAlignment(.center)
            }
            .padding(16)
            .frame(minWidth: 200)
            .presentationCompactAdaptation(.popover)
        }
    }
}
