//
//  ClubSubscriptionService.swift
//  TapInApp
//
//  Persists club subscriptions to UserDefaults.
//  Keyed by organizerName (exact string from iCal feed).
//

import Foundation
import Combine

final class ClubSubscriptionService: ObservableObject {
    static let shared = ClubSubscriptionService()

    @Published private(set) var subscribedOrganizers: [String] = []

    private let key = "subscribedClubOrganizers"

    private init() {
        load()
    }

    // MARK: - Public API

    func isSubscribed(_ organizerName: String) -> Bool {
        subscribedOrganizers.contains(organizerName)
    }

    func subscribe(_ organizerName: String) {
        guard !isSubscribed(organizerName) else { return }
        subscribedOrganizers.append(organizerName)
        persist()
    }

    func unsubscribe(_ organizerName: String) {
        subscribedOrganizers.removeAll { $0 == organizerName }
        persist()
    }

    func toggle(_ organizerName: String) {
        isSubscribed(organizerName) ? unsubscribe(organizerName) : subscribe(organizerName)
    }

    // MARK: - Display Name

    /// Returns a short display name for the pill label.
    /// Uses clubAcronym if provided, otherwise shortens organizerName.
    func displayName(for organizerName: String, acronym: String? = nil) -> String {
        if let acronym = acronym, !acronym.isEmpty {
            return acronym
        }
        let words = organizerName.components(separatedBy: " ")
        if organizerName.count <= 12 {
            return organizerName
        }
        let skip = ["the", "uc", "ucd", "a", "an"]
        let meaningful = words.first(where: { !skip.contains($0.lowercased()) }) ?? words[0]
        return meaningful
    }

    // MARK: - Private

    private func load() {
        subscribedOrganizers = UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    private func persist() {
        UserDefaults.standard.set(subscribedOrganizers, forKey: key)
    }
}
