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

    var body: some View {
        Button(action: onTap) {
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
            .background(
                isSelected
                    ? Color.ucdBlue
                    : (colorScheme == .dark ? Color(hex: "#1e293b") : Color.white)
            )
            .foregroundColor(
                isSelected
                    ? .white
                    : (colorScheme == .dark ? Color(hex: "#cbd5e1") : Color(hex: "#334155"))
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(
                        isSelected
                            ? Color.clear
                            : (colorScheme == .dark ? Color(hex: "#334155") : Color(hex: "#e2e8f0")),
                        lineWidth: 1
                    )
            )
            .shadow(color: isSelected ? Color.ucdBlue.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
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
