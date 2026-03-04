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

    // Gemini glow animation state (For You pill only)
    @State private var rotation: Double = 0
    @State private var glowOpacity: Double = 0.4

    private let geminiColors: [Color] = [
        Color(hex: "#3b82f6"),
        Color(hex: "#8b5cf6"),
        Color(hex: "#FFBF00"),
        Color(hex: "#ec4899"),
        Color(hex: "#3b82f6")
    ]

    var body: some View {
        if showGeminiGlow {
            geminiPill
        } else {
            simplePill
        }
    }

    // MARK: - Simple Pill (all categories except selected "For You")

    private var simplePill: some View {
        HStack(spacing: 6) {
            if !category.icon.isEmpty {
                Image(systemName: category.icon)
                    .font(.system(size: 14))
            }
            Text(category.name)
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
        }
        .padding(.horizontal, isSelected ? 20 : 16)
        .frame(height: 36)
        .foregroundStyle(simpleForeground)
        .background(simpleFillColor, in: Capsule())
        .overlay(simpleBorder)
        .contentShape(Capsule())
        .onTapGesture(perform: onTap)
        .accessibilityAddTraits(.isButton)
    }

    private var simpleFillColor: Color {
        if isSelected {
            return colorScheme == .dark ? Color(hex: "#1a1060") : Color.accentCoral
        } else {
            return colorScheme == .dark ? Color(hex: "#1a2033") : Color.white
        }
    }

    private var simpleForeground: Color {
        if isSelected {
            return .white
        } else {
            return colorScheme == .dark ? Color(hex: "#cbd5e1") : Color(hex: "#334155")
        }
    }

    @ViewBuilder
    private var simpleBorder: some View {
        if !isSelected {
            Capsule()
                .stroke(
                    colorScheme == .dark ? Color(hex: "#334155") : Color(hex: "#e2e8f0"),
                    lineWidth: 1
                )
        }
    }

    // MARK: - Gemini Pill (selected "For You" only)

    private var geminiPill: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                if !category.icon.isEmpty {
                    Image(systemName: category.icon)
                        .font(.system(size: 14))
                        .symbolEffect(.pulse, options: .repeating, isActive: true)
                }
                Text(category.name)
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, 20)
            .frame(height: 36)
            .foregroundStyle(colorScheme == .dark ? .white.opacity(0.95) : Color(hex: "#6d28d9"))
            .background(
                colorScheme == .dark ? Color(hex: "#1a1a2e").opacity(0.9) : Color(hex: "#faf5ff").opacity(0.95),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(
                        AngularGradient(colors: geminiColors, center: .center, angle: .degrees(rotation)),
                        lineWidth: 1.8
                    )
            )
        }
        .buttonStyle(.plain)
        .background(
            Capsule()
                .fill(AngularGradient(colors: geminiColors, center: .center, angle: .degrees(rotation + 90)))
                .padding(-3)
                .blur(radius: 5)
                .opacity(glowOpacity)
        )
        .shadow(color: Color(hex: "#8b5cf6").opacity(0.3), radius: 6, x: 0, y: 2)
        .onAppear {
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                glowOpacity = 0.15
            }
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
