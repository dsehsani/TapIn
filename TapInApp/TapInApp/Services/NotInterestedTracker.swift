//
//  NotInterestedTracker.swift
//  TapInApp
//
//  Tracks articles and events the user has dismissed via "Not Interested".
//  Persisted to UserDefaults so dismissals survive app restarts.
//

import Foundation

class NotInterestedTracker {
    static let shared = NotInterestedTracker()

    private var dismissedEventIDs: Set<String>
    private var dismissedArticleURLs: Set<String>

    private let eventsKey = "notInterested_events"
    private let articlesKey = "notInterested_articles"

    private init() {
        let savedEvents = UserDefaults.standard.stringArray(forKey: eventsKey) ?? []
        dismissedEventIDs = Set(savedEvents)

        let savedArticles = UserDefaults.standard.stringArray(forKey: articlesKey) ?? []
        dismissedArticleURLs = Set(savedArticles)
    }

    func dismissEvent(_ event: CampusEvent) {
        dismissedEventIDs.insert(event.id.uuidString)
        UserDefaults.standard.set(Array(dismissedEventIDs), forKey: eventsKey)
    }

    func dismissArticle(_ article: NewsArticle) {
        if let url = article.articleURL {
            dismissedArticleURLs.insert(url)
        } else {
            dismissedArticleURLs.insert(article.title)
        }
        UserDefaults.standard.set(Array(dismissedArticleURLs), forKey: articlesKey)
    }

    func isEventDismissed(_ event: CampusEvent) -> Bool {
        dismissedEventIDs.contains(event.id.uuidString)
    }

    func isArticleDismissed(_ article: NewsArticle) -> Bool {
        if let url = article.articleURL {
            return dismissedArticleURLs.contains(url)
        }
        return dismissedArticleURLs.contains(article.title)
    }
}
