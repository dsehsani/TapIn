//
//  OnboardingManager.swift
//  TapInApp
//
//  MARK: - Onboarding Tip Manager
//  Singleton that controls which contextual tooltip is active.
//  Tips show in a fixed sequence and are persisted so each tip only appears once.
//

import SwiftUI

enum OnboardingTip: String, CaseIterable {
    case searchBar
    case categoryPills
    case dailyBriefing
    case navigationBar
    case featuredGame
    case leaderboard
    case editProfile

    var userDefaultsKey: String {
        "onboarding_tip_dismissed_\(rawValue)"
    }
}

@Observable
final class OnboardingManager {
    static let shared = OnboardingManager()

    /// The currently visible tip (nil = nothing showing).
    var activeTip: OnboardingTip?

    /// Fixed display order.
    private let sequence: [OnboardingTip] = [.searchBar, .categoryPills, .dailyBriefing, .navigationBar, .featuredGame, .leaderboard, .editProfile]

    private init() {}

    // MARK: - Public API

    /// A view calls this on appear. The tip is granted only if it's next in
    /// the sequence AND hasn't been dismissed yet.
    func requestTip(_ tip: OnboardingTip) {
        guard activeTip == nil,
              !isDismissed(tip),
              tip == nextTipInSequence()
        else { return }

        withAnimation(.easeInOut(duration: 0.3)) {
            activeTip = tip
        }
    }

    /// Dismiss the current tip and persist the dismissal.
    func dismissTip(_ tip: OnboardingTip) {
        UserDefaults.standard.set(true, forKey: tip.userDefaultsKey)
        withAnimation(.easeInOut(duration: 0.2)) {
            if activeTip == tip {
                activeTip = nil
            }
        }
    }

    /// Auto-dismiss a tip when its precondition isn't met (e.g., year already set).
    func skipTipIfNeeded(_ tip: OnboardingTip) {
        guard !isDismissed(tip) else { return }
        UserDefaults.standard.set(true, forKey: tip.userDefaultsKey)
    }

    /// Whether a specific tip should be visible right now.
    func shouldShowTip(_ tip: OnboardingTip) -> Bool {
        activeTip == tip
    }

    /// Reset all tips (for debug / testing).
    func resetAllTips() {
        for tip in OnboardingTip.allCases {
            UserDefaults.standard.removeObject(forKey: tip.userDefaultsKey)
        }
        activeTip = nil
    }

    // MARK: - Private

    private func isDismissed(_ tip: OnboardingTip) -> Bool {
        UserDefaults.standard.bool(forKey: tip.userDefaultsKey)
    }

    private func nextTipInSequence() -> OnboardingTip? {
        sequence.first { !isDismissed($0) }
    }
}
