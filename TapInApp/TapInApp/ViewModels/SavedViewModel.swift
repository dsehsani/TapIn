//
//  SavedViewModel.swift
//  TapInApp
//
//  Created by Darius Ehsani on 1/29/26.
//
//  MARK: - Saved Articles ViewModel
//  Manages bookmarked/saved content
//  TODO: ADD PERSISTENCE LOGIC HERE (UserDefaults, CoreData, or backend)
//

import Foundation
import SwiftUI
import Combine

class SavedViewModel: ObservableObject {
    @Published var savedArticles: [NewsArticle] = []
    @Published var savedEvents: [CampusEvent] = []

    init() {
        loadSavedContent()
    }

    func saveArticle(_ article: NewsArticle) {
        if !savedArticles.contains(where: { $0.id == article.id }) {
            savedArticles.append(article)
            persistContent()
        }
    }

    func removeArticle(_ article: NewsArticle) {
        savedArticles.removeAll { $0.id == article.id }
        persistContent()
    }

    func isArticleSaved(_ article: NewsArticle) -> Bool {
        return savedArticles.contains(where: { $0.id == article.id })
    }

    func toggleArticleSaved(_ article: NewsArticle) {
        if isArticleSaved(article) {
            removeArticle(article)
        } else {
            saveArticle(article)
        }
    }

    func saveEvent(_ event: CampusEvent) {
        if !savedEvents.contains(where: { $0.id == event.id }) {
            savedEvents.append(event)
            persistContent()
        }
    }

    func removeEvent(_ event: CampusEvent) {
        savedEvents.removeAll { $0.id == event.id }
        persistContent()
    }

    func isEventSaved(_ event: CampusEvent) -> Bool {
        return savedEvents.contains(where: { $0.id == event.id })
    }

    // TODO: IMPLEMENT PERSISTENCE
    private func loadSavedContent() {
        // Load from UserDefaults/CoreData
    }

    private func persistContent() {
        // Save to UserDefaults/CoreData
    }
}
