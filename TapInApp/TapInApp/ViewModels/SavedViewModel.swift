//
//  SavedViewModel.swift
//  TapInApp
//
//  Created by Darius Ehsani on 1/29/26.
//
//  MARK: - Saved Articles ViewModel
//  Manages bookmarked/saved content with local + backend sync.
//  Local UserDefaults is the primary store; backend Firestore syncs
//  so saved data persists across devices.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class SavedViewModel: ObservableObject {
    @Published var savedArticles: [NewsArticle] = []
    @Published var savedEvents: [CampusEvent] = []

    // MARK: - Toast State
    @Published var toastMessage: String = ""
    @Published var toastIcon: String = "bookmark.fill"
    @Published var toastIsSaved: Bool = true
    @Published var showToast: Bool = false
    private var toastTask: Task<Void, Never>?

    // MARK: - Recently Saved Tracking
    /// Maps stable item keys to save timestamps for "Recently Saved" pills
    @Published var recentlySavedKeys: Set<String> = []
    private var recentTimers: [String: Task<Void, Never>] = [:]
    /// How long the "Just saved" pill stays visible (seconds)
    private let recentDuration: TimeInterval = 120

    private let savedEventsKey = "savedEvents"
    private let savedArticlesKey = "savedArticles"

    /// Callbacks for notification bell wiring (set by ContentView)
    var onEventSaved: ((CampusEvent) -> Void)?
    var onEventRemoved: ((CampusEvent) -> Void)?

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
        // Fetch from backend and merge (non-blocking)
        Task { await fetchFromBackend() }
    }

    // MARK: - Articles (match by articleURL since UUIDs regenerate)

    func saveArticle(_ article: NewsArticle) {
        if !isArticleSaved(article) {
            savedArticles.append(article)
            persistContent()
            Task { await syncSaveArticle(article) }
            let key = article.articleURL ?? article.id.uuidString
            markAsRecentlySaved(key: "article_\(key)")
        }
    }

    func removeArticle(_ article: NewsArticle) {
        savedArticles.removeAll { matchesArticle($0, article) }
        persistContent()
        Task { await syncRemoveArticle(article) }
    }

    func isArticleSaved(_ article: NewsArticle) -> Bool {
        return savedArticles.contains(where: { matchesArticle($0, article) })
    }

    func toggleArticleSaved(_ article: NewsArticle) {
        let wasSaved = isArticleSaved(article)
        if wasSaved {
            removeArticle(article)
        } else {
            saveArticle(article)
        }
        showSavedToast(
            itemType: "Article",
            saved: !wasSaved
        )
    }

    // MARK: - Recently Saved Helpers

    func isRecentlySaved(articleKey: String) -> Bool {
        recentlySavedKeys.contains("article_\(articleKey)")
    }

    func isRecentlySavedEvent(title: String, date: Date) -> Bool {
        recentlySavedKeys.contains("event_\(title)_\(date.timeIntervalSince1970)")
    }

    private func markAsRecentlySaved(key: String) {
        recentlySavedKeys.insert(key)
        recentTimers[key]?.cancel()
        recentTimers[key] = Task {
            try? await Task.sleep(for: .seconds(recentDuration))
            guard !Task.isCancelled else { return }
            recentlySavedKeys.remove(key)
        }
    }

    // MARK: - Toast Helper

    private func showSavedToast(itemType: String, saved: Bool) {
        toastTask?.cancel()
        toastMessage = saved ? "\(itemType) saved to Saved tab" : "\(itemType) removed from Saved"
        toastIcon = saved ? "bookmark.fill" : "bookmark.slash"
        toastIsSaved = saved
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            showToast = true
        }
        toastTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                showToast = false
            }
        }
    }

    /// Match by articleURL (stable across RSS refreshes) or fall back to id
    private func matchesArticle(_ a: NewsArticle, _ b: NewsArticle) -> Bool {
        if let urlA = a.articleURL, let urlB = b.articleURL, !urlA.isEmpty, !urlB.isEmpty {
            return urlA == urlB
        }
        return a.id == b.id
    }

    // MARK: - Events (match by title + date since UUIDs regenerate)

    func saveEvent(_ event: CampusEvent) {
        if !isEventSaved(event) {
            savedEvents.append(event)
            persistContent()
            Task { await syncSaveEvent(event) }
            Task { await NotificationService.shared.scheduleReminders(for: event) }
            onEventSaved?(event)
            markAsRecentlySaved(key: "event_\(event.title)_\(event.date.timeIntervalSince1970)")
        }
    }

    func removeEvent(_ event: CampusEvent) {
        savedEvents.removeAll { matchesEvent($0, event) }
        persistContent()
        Task { await syncRemoveEvent(event) }
        NotificationService.shared.cancelReminders(for: event)
        onEventRemoved?(event)
    }

    func isEventSaved(_ event: CampusEvent) -> Bool {
        return savedEvents.contains(where: { matchesEvent($0, event) })
    }

    func toggleEventSaved(_ event: CampusEvent) {
        let wasSaved = isEventSaved(event)
        if wasSaved {
            removeEvent(event)
        } else {
            saveEvent(event)
        }
        showSavedToast(
            itemType: "Event",
            saved: !wasSaved
        )
    }

    private func matchesEvent(_ a: CampusEvent, _ b: CampusEvent) -> Bool {
        return a.title == b.title && a.date == b.date
    }

    /// Stable identifier for an event (delegates to CampusEvent.stableNotificationId)
    private func eventStableId(_ event: CampusEvent) -> String {
        event.stableNotificationId
    }

    // MARK: - Local Persistence

    private func loadSavedContent() {
        if let data = UserDefaults.standard.data(forKey: savedEventsKey),
           let events = try? JSONDecoder().decode([CampusEvent].self, from: data) {
            savedEvents = events
        }
        if let data = UserDefaults.standard.data(forKey: savedArticlesKey),
           let articles = try? JSONDecoder().decode([NewsArticle].self, from: data) {
            savedArticles = articles
        }
    }

    private func persistContent() {
        if let data = try? JSONEncoder().encode(savedEvents) {
            UserDefaults.standard.set(data, forKey: savedEventsKey)
        }
        if let data = try? JSONEncoder().encode(savedArticles) {
            UserDefaults.standard.set(data, forKey: savedArticlesKey)
        }
    }

    // MARK: - Backend Sync

    /// Fetches saved articles and events from the backend and merges with local data.
    /// Called on init — merges so no local data is lost.
    func fetchFromBackend() async {
        guard let token = AppState.shared.backendToken else { return }

        // Fetch saved articles
        if let remoteArticles = await fetchSavedArticles(token: token) {
            mergeArticles(remoteArticles)
        }

        // Fetch saved events
        if let remoteEvents = await fetchSavedEvents(token: token) {
            mergeEvents(remoteEvents)
        }

        persistContent()
    }

    private func mergeArticles(_ remote: [NewsArticle]) {
        for article in remote {
            if !savedArticles.contains(where: { matchesArticle($0, article) }) {
                savedArticles.append(article)
            }
        }
    }

    private func mergeEvents(_ remote: [CampusEvent]) {
        for event in remote {
            if !savedEvents.contains(where: { matchesEvent($0, event) }) {
                savedEvents.append(event)
            }
        }
    }

    // MARK: - Backend API Calls

    private func authRequest(url: String, method: String, body: [String: Any]? = nil) async -> (Data, Int)? {
        guard let token = AppState.shared.backendToken,
              let requestURL = URL(string: url) else { return nil }

        var request = URLRequest(url: requestURL)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else { return nil }
        return (data, http.statusCode)
    }

    // -- Articles --

    private func fetchSavedArticles(token: String) async -> [NewsArticle]? {
        guard let (data, status) = await authRequest(url: APIConfig.savedArticlesURL, method: "GET"),
              (200...299).contains(status) else { return nil }

        struct Response: Decodable {
            let success: Bool
            let savedArticles: [SavedArticleEntry]
        }
        struct SavedArticleEntry: Decodable {
            let articleId: String?
            let title: String?
            let excerpt: String?
            let imageURL: String?
            let category: String?
            let author: String?
            let articleURL: String?
            let publishDate: String?
        }

        guard let result = try? JSONDecoder().decode(Response.self, from: data),
              result.success else { return nil }

        let formatter = ISO8601DateFormatter()
        return result.savedArticles.compactMap { entry in
            guard let title = entry.title, !title.isEmpty else { return nil }
            return NewsArticle(
                title: title,
                excerpt: entry.excerpt ?? "",
                imageURL: entry.imageURL ?? "",
                category: entry.category ?? "",
                timestamp: entry.publishDate.flatMap { formatter.date(from: $0) } ?? Date(),
                author: entry.author,
                articleURL: entry.articleURL
            )
        }
    }

    private func syncSaveArticle(_ article: NewsArticle) async {
        let formatter = ISO8601DateFormatter()
        let body: [String: Any] = [
            "articleId": article.articleURL ?? article.id.uuidString,
            "title": article.title,
            "excerpt": article.excerpt,
            "imageURL": article.imageURL,
            "category": article.category,
            "author": article.author ?? "",
            "articleURL": article.articleURL ?? "",
            "publishDate": formatter.string(from: article.timestamp)
        ]
        _ = await authRequest(url: APIConfig.savedArticlesURL, method: "POST", body: body)
    }

    private func syncRemoveArticle(_ article: NewsArticle) async {
        let articleId = article.articleURL ?? article.id.uuidString
        _ = await authRequest(url: APIConfig.unsaveArticleURL(articleId: articleId), method: "DELETE")
    }

    // -- Events --

    private func fetchSavedEvents(token: String) async -> [CampusEvent]? {
        guard let (data, status) = await authRequest(url: APIConfig.eventRSVPsURL, method: "GET"),
              (200...299).contains(status) else { return nil }

        struct Response: Decodable {
            let success: Bool
            let eventRSVPs: [EventRSVPEntry]
        }
        struct EventRSVPEntry: Decodable {
            let eventId: String?
            let eventTitle: String?
            let eventDate: String?
            let eventLocation: String?
            let eventDescription: String?
        }

        guard let result = try? JSONDecoder().decode(Response.self, from: data),
              result.success else { return nil }

        let formatter = ISO8601DateFormatter()
        return result.eventRSVPs.compactMap { entry in
            guard let title = entry.eventTitle, !title.isEmpty,
                  let dateStr = entry.eventDate,
                  let date = formatter.date(from: dateStr) else { return nil }
            return CampusEvent(
                title: title,
                description: entry.eventDescription ?? "",
                date: date,
                location: entry.eventLocation ?? "TBD"
            )
        }
    }

    private func syncSaveEvent(_ event: CampusEvent) async {
        let formatter = ISO8601DateFormatter()
        let body: [String: Any] = [
            "eventId": eventStableId(event),
            "eventTitle": event.title,
            "eventDate": formatter.string(from: event.date),
            "eventLocation": event.location,
            "eventDescription": event.description
        ]
        _ = await authRequest(url: APIConfig.eventRSVPsURL, method: "POST", body: body)
    }

    private func syncRemoveEvent(_ event: CampusEvent) async {
        let eventId = eventStableId(event)
        _ = await authRequest(url: APIConfig.cancelRSVPURL(eventId: eventId), method: "DELETE")
    }
}
