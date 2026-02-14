//
//  Category.swift
//  TapInApp
//
//  Created by Darius Ehsani on 1/29/26.
//

import Foundation

struct Category: Identifiable, Hashable {
    let id: UUID
    let name: String
    let icon: String
    let isSelected: Bool

    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "",
        isSelected: Bool = false
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.isSelected = isSelected
    }
}

// MARK: - The Aggie News Categories
extension Category {
    static let allCategories: [Category] = [
        Category(name: "All News", icon: "newspaper.fill", isSelected: true),
        Category(name: "Campus", icon: "building.2.fill"),
        Category(name: "City", icon: "building.fill"),
        Category(name: "Opinion", icon: "text.bubble.fill"),
        Category(name: "Features", icon: "star.fill"),
        Category(name: "Arts & Culture", icon: "paintpalette.fill"),
        Category(name: "Sports", icon: "sportscourt.fill"),
        Category(name: "Science & Tech", icon: "atom")
    ]

    /// Maps category display name to NewsService.NewsCategory
    var newsCategory: NewsService.NewsCategory {
        switch name {
        case "All News": return .all
        case "Campus": return .campus
        case "City": return .city
        case "Opinion": return .opinion
        case "Features": return .features
        case "Arts & Culture": return .artsCulture
        case "Sports": return .sports
        case "Science & Tech": return .scienceTech
        default: return .all
        }
    }
}
