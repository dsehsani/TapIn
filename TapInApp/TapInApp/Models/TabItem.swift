//
//  TabItem.swift
//  TapInApp
//
//  Created by Darius Ehsani on 1/29/26.
//

import SwiftUI

enum TabItem: String, CaseIterable {
    case news = "News"
    case campus = "Events"
    case games = "Games"
    case saved = "Saved"
    case profile = "Profile"
    case search = "Search"

    var icon: String {
        switch self {
        case .news: return "newspaper"
        case .campus: return "building.2"
        case .games: return "puzzlepiece.extension"
        case .saved: return "bookmark"
        case .profile: return "person.circle"
        case .search: return "magnifyingglass"
        }
        
    }
    
    

    /// Tabs shown in the tab bar (Profile opens via avatar sheet)
    static let visibleTabs: [TabItem] = [.news, .campus, .games, .saved, .search]

    var iconFilled: String {
        switch self {
        case .news: return "newspaper.fill"
        case .campus: return "building.2.fill"
        case .games: return "puzzlepiece.extension.fill"
        case .saved: return "bookmark.fill"
        case .profile: return "person.circle.fill"
        case .search: return "magnifyingglass"
        }
    }
}
