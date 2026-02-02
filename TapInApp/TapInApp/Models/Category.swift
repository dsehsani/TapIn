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

// MARK: - Sample Categories
extension Category {
    static let allCategories: [Category] = [
        Category(name: "Top Stories", icon: "", isSelected: true),
        Category(name: "Research", icon: "flask.fill"),
        Category(name: "Campus", icon: "building.2.fill"),
        Category(name: "Athletics", icon: "sportscourt.fill")
    ]
}
