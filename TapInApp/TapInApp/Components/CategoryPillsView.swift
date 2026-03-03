//
//  CategoryPillsView.swift
//  TapInApp
//
//  Created by Darius Ehsani on 1/29/26.
//

import SwiftUI

struct CategoryPillsView: View {
    @Binding var selectedCategory: String
    var categories: [Category]
    var onCategoryTap: (String) -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(categories) { category in
                    CategoryPill(
                        category: category,
                        isSelected: selectedCategory == category.name,
                        colorScheme: colorScheme
                    ) {
                        onCategoryTap(category.name)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }
}

struct CategoryPill: View {
    let category: Category
    let isSelected: Bool
    let colorScheme: ColorScheme
    let onTap: () -> Void

    private var isForYou: Bool { category.name == "For You" }
    private var showGeminiGlow: Bool { isForYou && isSelected }

    // Gemini-style rotating gradient (matches AISummaryBadge)
    @State private var rotation: Double = 0
    @State private var glowOpacity: Double = 0.4

    private let geminiColors: [Color] = [
        Color(hex: "#3b82f6"),  // Blue
        Color(hex: "#8b5cf6"),  // Purple
        Color(hex: "#FFBF00"),  // UC Davis Gold
        Color(hex: "#ec4899"),  // Pink
        Color(hex: "#3b82f6")   // Blue (loop)
    ]

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                if !category.icon.isEmpty {
                    Image(systemName: category.icon)
                        .font(.system(size: 14))
                        .symbolEffect(.pulse, options: .repeating, isActive: showGeminiGlow)
                }

                Text(category.name)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
            }
            .padding(.horizontal, isSelected ? 20 : 16)
            .frame(height: 36)
            .foregroundColor(pillForeground)
            .background(Capsule().fill(pillBackground))
            .clipShape(Capsule())
            .overlay(pillBorder)
        }
        .buttonStyle(PlainButtonStyle())
        // Gemini glow sits behind the button so it's not clipped
        .background(geminiGlowBackground)
        .shadow(color: pillShadowColor, radius: showGeminiGlow ? 6 : 4, x: 0, y: 2)
        .onAppear {
            guard isForYou else { return }
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                glowOpacity = 0.15
            }
        }
    }

    // MARK: - Extracted sub-views to help the compiler

    private var pillBackground: some ShapeStyle {
        if showGeminiGlow {
            return AnyShapeStyle(colorScheme == .dark ? Color(hex: "#1a1a2e").opacity(0.9) : Color(hex: "#faf5ff").opacity(0.95))
        } else if isSelected {
            return AnyShapeStyle(colorScheme == .dark ? Color(hex: "#1a1060") : Color.accentCoral)
        } else {
            return AnyShapeStyle(colorScheme == .dark ? Color(hex: "#1a2033") : Color.white)
        }
    }

    private var pillForeground: Color {
        if showGeminiGlow {
            return colorScheme == .dark ? .white.opacity(0.95) : Color(hex: "#6d28d9")
        } else if isSelected {
            return .white
        } else {
            return colorScheme == .dark ? Color(hex: "#cbd5e1") : Color(hex: "#334155")
        }
    }

    @ViewBuilder
    private var pillBorder: some View {
        if showGeminiGlow {
            // Rotating rainbow gradient border
            Capsule()
                .stroke(
                    AngularGradient(
                        colors: geminiColors,
                        center: .center,
                        angle: .degrees(rotation)
                    ),
                    lineWidth: 1.8
                )
        } else if !isSelected {
            Capsule()
                .stroke(
                    colorScheme == .dark ? Color(hex: "#334155") : Color(hex: "#e2e8f0"),
                    lineWidth: 1
                )
        }
    }

    @ViewBuilder
    private var geminiGlowBackground: some View {
        if showGeminiGlow {
            Capsule()
                .fill(
                    AngularGradient(
                        colors: geminiColors,
                        center: .center,
                        angle: .degrees(rotation + 90)
                    )
                )
                .blur(radius: 8)
                .opacity(glowOpacity)
                .scaleEffect(1.08)
        }
    }

    private var pillShadowColor: Color {
        if showGeminiGlow {
            return Color(hex: "#8b5cf6").opacity(0.3)
        } else if isSelected {
            return colorScheme == .dark ? Color(hex: "#1a1060").opacity(0.4) : Color.accentCoral.opacity(0.25)
        } else {
            return .clear
        }
    }
}

#Preview {
    VStack {
        CategoryPillsView(
            selectedCategory: .constant("Top Stories"),
            categories: Category.allCategories,
            onCategoryTap: { _ in }
        )
        Spacer()
    }
    .background(Color.backgroundLight)
}
