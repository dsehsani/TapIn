//
//  SavedViewModel.swift
//  TapInApp
//
//  Created by Darius Ehsani on 1/29/26.
//
//  MARK: - Saved Articles ViewModel
//  Manages bookmarked/saved content with UserDefaults persistence
//

import Foundation
import SwiftUI
import Combine

class SavedViewModel: ObservableObject {
    @Published var savedArticles: [NewsArticle] = []
    @Published var savedEvents: [CampusEvent] = []

    private let savedEventsKey = "savedEvents"

    // MARK: - Temporal Filtering

    var upcomingEvents: [CampusEvent] {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return savedEvents
            .filter { $0.date >= startOfToday }
            .sorted { $0.date < $1.date }
    }

    var attendedEvents: [CampusEvent] {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return savedEvents
            .filter { $0.date < startOfToday }
            .sorted { $0.date > $1.date }
    }

    init() {
        loadSavedContent()
    }

    // MARK: - Articles

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

    // MARK: - Events (match by title + date since UUIDs regenerate)

    func saveEvent(_ event: CampusEvent) {
        if !isEventSaved(event) {
            savedEvents.append(event)
            persistContent()
        }
    }

    func removeEvent(_ event: CampusEvent) {
        savedEvents.removeAll { matchesEvent($0, event) }
        persistContent()
    }

    func isEventSaved(_ event: CampusEvent) -> Bool {
        return savedEvents.contains(where: { matchesEvent($0, event) })
    }

    func toggleEventSaved(_ event: CampusEvent) {
        if isEventSaved(event) {
            removeEvent(event)
        } else {
            saveEvent(event)
        }
    }

    private func matchesEvent(_ a: CampusEvent, _ b: CampusEvent) -> Bool {
        return a.title == b.title && a.date == b.date
    }

    // MARK: - Persistence

    private func loadSavedContent() {
        if let data = UserDefaults.standard.data(forKey: savedEventsKey),
           let events = try? JSONDecoder().decode([CampusEvent].self, from: data) {
            savedEvents = events
        }
    }

    private func persistContent() {
        if let data = try? JSONEncoder().encode(savedEvents) {
            UserDefaults.standard.set(data, forKey: savedEventsKey)
        }
    }
}
