# TapIn — Club Subscriptions + Dynamic Filter Pills

## Overview

Users can follow specific clubs directly from an event's detail view. Each followed club gets its own pill in the main filter bar, showing only that club's upcoming events. Pills appear and disappear automatically based on what the user is subscribed to.

**End state of the pill bar (example):**
```
For You · All Events · Navigators · AIChE · [UC Davis if populated]
```

Tapping a club pill filters the event list to that club only. Following/unfollowing is done from the organizer row in `EventDetailView`.

---

## What Changes

- New: `TapInApp/Services/ClubSubscriptionService.swift` — persistence + subscription logic
- `TapInApp/ViewModels/CampusViewModel.swift` — club filter state + apply logic
- `TapInApp/Views/CampusView.swift` — render dynamic club pills in the pill bar
- `TapInApp/Views/EventDetailView.swift` — Follow / Following button next to organizer

---

## Change 1: New `ClubSubscriptionService.swift`

Create this as a singleton in `TapInApp/Services/`:

```swift
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
        // Take first word if it's long, otherwise use up to 12 chars
        let words = organizerName.components(separatedBy: " ")
        if organizerName.count <= 12 {
            return organizerName
        }
        // Skip generic leading words like "The", "UC", "UCD"
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
```

---

## Change 2: `CampusViewModel.swift` — Club Filter State

### 2a. Add selected club organizer state

```swift
/// When non-nil, the event list is filtered to this organizer only.
/// Set by tapping a club pill. Cleared when any other pill is tapped.
@Published var selectedClubOrganizer: String? = nil
```

### 2b. Update `filterEvents(by:)` to clear club selection

```swift
func filterEvents(by type: EventFilterType) {
    selectedClubOrganizer = nil    // ← clear club filter when switching to a standard pill
    filterType = type
    applyFilters()
}
```

### 2c. Add `filterByClub()`

```swift
func filterByClub(_ organizerName: String) {
    selectedClubOrganizer = organizerName
    applyFilters()
}
```

### 2d. Update `applyFilters()` — add club filter case

In the `switch filterType` block, add a guard at the top:

```swift
// Club filter takes priority over standard filter type
if let club = selectedClubOrganizer {
    events = upcoming.filter { $0.organizerName == club }
    return
}

switch filterType {
case .all:
    events = upcoming
case .forYou:
    events = EventPreferenceEngine.shared.recommend(from: upcoming)
case .official:
    events = upcoming.filter { $0.isOfficial }
}
```

### 2e. Add a helper to check if a subscribed club has upcoming events

Only show a club's pill if they actually have upcoming events — no pill for a club that hasn't posted anything yet.

```swift
/// Returns subscribed organizer names that have at least one upcoming event.
var activeSubscribedClubs: [String] {
    let upcoming = allEvents.filter { $0.date >= Calendar.current.startOfDay(for: Date()) }
    return ClubSubscriptionService.shared.subscribedOrganizers.filter { organizer in
        upcoming.contains { $0.organizerName == organizer }
    }
}
```

---

## Change 3: `CampusView.swift` — Dynamic Club Pills in Pill Bar

### 3a. Observe `ClubSubscriptionService`

Add to `CampusView`:

```swift
@ObservedObject private var subscriptionService = ClubSubscriptionService.shared
```

### 3b. Replace the pill bar `ForEach` with a combined list

The pill bar now renders three groups in order:
1. Permanent pills (`For You`, `All Events`)
2. UC Davis (conditional, already wired)
3. Club subscription pills (one per active subscribed club)

```swift
ScrollView(.horizontal, showsIndicators: false) {
    HStack(spacing: 12) {

        // ── Group 1 + 2: Permanent + UC Davis ────────────────────────────
        ForEach(EventFilterType.permanentFilters
                + (viewModel.hasUCDavisEvents ? [.official] : []),
                id: \.self) { filter in

            Button(action: {
                if filter == .forYou {
                    viewModel.setProfileEvents(savedViewModel.savedEvents)
                }
                viewModel.filterEvents(by: filter)
            }) {
                pillLabel(for: filter.rawValue,
                          isSelected: viewModel.selectedClubOrganizer == nil
                                      && viewModel.filterType == filter)
            }
        }

        // ── Group 3: Club subscription pills ─────────────────────────────
        ForEach(viewModel.activeSubscribedClubs, id: \.self) { organizer in
            // Look up acronym from any event by this organizer
            let acronym = viewModel.allEvents
                .first { $0.organizerName == organizer }?
                .clubAcronym

            let label = subscriptionService.displayName(
                for: organizer,
                acronym: acronym
            )

            Button(action: {
                viewModel.filterByClub(organizer)
            }) {
                pillLabel(for: label,
                          isSelected: viewModel.selectedClubOrganizer == organizer,
                          isClub: true)
            }
        }
    }
    .padding(.horizontal, 16)
}
```

### 3c. Extract `pillLabel` as a private helper view

To avoid duplicating pill styling, extract the pill appearance into a helper:

```swift
private func pillLabel(for title: String,
                       isSelected: Bool,
                       isClub: Bool = false) -> some View {
    HStack(spacing: 4) {
        if isClub {
            // Small dot indicator for club pills to distinguish them visually
            Circle()
                .fill(isSelected ? Color.white : Color.accentPurple)
                .frame(width: 5, height: 5)
        }
        Text(title)
            .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
    .background(
        isSelected
            ? (colorScheme == .dark ? Color(hex: "#1a1060") : Color.accentCoral)
            : (colorScheme == .dark ? Color(hex: "#1a2033") : .white)
    )
    .foregroundColor(
        isSelected
            ? .white
            : (colorScheme == .dark ? Color(hex: "#cbd5e1") : Color(hex: "#334155"))
    )
    .clipShape(Capsule())
    .overlay(
        Capsule().strokeBorder(
            isSelected
                ? Color.clear
                : (isClub
                    ? Color.accentPurple.opacity(0.4)
                    : (colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#e2e8f0"))),
            lineWidth: 1
        )
    )
}
```

Club pills get a subtle purple dot and purple border when unselected — visually distinct from the permanent pills but not noisy.

---

## Change 4: `EventDetailView.swift` — Follow Button

### 4a. Add subscription service reference

```swift
@ObservedObject private var subscriptionService = ClubSubscriptionService.shared
```

### 4b. Replace the organizer row

Find the existing organizer `HStack` (around line 57) and replace it with a version that includes the Follow button:

```swift
// MARK: - Organizer
if let organizer = event.organizerName {
    HStack(spacing: 8) {
        Image(systemName: "person.2.fill")
            .font(.system(size: 14))
            .foregroundColor(Color.ucdBlue)
        Text(organizer)
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#334155"))
            .lineLimit(1)

        Spacer()

        // Follow / Following button
        let isFollowing = subscriptionService.isSubscribed(organizer)
        Button(action: {
            subscriptionService.toggle(organizer)
        }) {
            HStack(spacing: 4) {
                Image(systemName: isFollowing ? "checkmark" : "plus")
                    .font(.system(size: 11, weight: .bold))
                Text(isFollowing ? "Following" : "Follow")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(isFollowing ? Color.ucdBlue : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isFollowing
                        ? Color.ucdBlue.opacity(0.12)
                        : Color.ucdBlue)
            )
            .overlay(
                Capsule().strokeBorder(
                    isFollowing ? Color.ucdBlue.opacity(0.4) : Color.clear,
                    lineWidth: 1
                )
            )
        }
        .animation(.easeInOut(duration: 0.15), value: isFollowing)
    }
}
```

The button animates between `+ Follow` (solid blue) and `✓ Following` (outlined blue) states.

---

## Acceptance Criteria

- [ ] Following a club from `EventDetailView` immediately adds a pill for that club in the Events pill bar.
- [ ] Unfollowing removes the pill from the bar.
- [ ] Club pills only appear for subscribed clubs that have at least one upcoming event — clubs with no upcoming events are hidden even if subscribed.
- [ ] Tapping a club pill filters the event list to that club's events only, and highlights the pill as selected.
- [ ] Tapping any permanent pill (`For You`, `All Events`) deselects the club filter and returns to normal behavior.
- [ ] Club pills display `clubAcronym` when available, otherwise a shortened version of `organizerName`.
- [ ] Club pills have a small purple dot and purple border to visually distinguish them from permanent pills.
- [ ] Subscriptions persist across app launches via UserDefaults.
- [ ] The `+ Follow` / `✓ Following` button animates smoothly between states.
- [ ] Official UC Davis events (no organizer) do not show a Follow button in their detail view.
- [ ] Subscribing to 0 clubs shows the standard `For You · All Events` pill bar — no empty space.
- [ ] A project-wide search for `studentPosted` returns zero results (from the filter cleanup — keep it gone).

---

## Notes for the Implementer

- `ClubSubscriptionService` is intentionally separate from `SavedViewModel` — subscriptions are a different concept from saved events and shouldn't be mixed.
- `activeSubscribedClubs` filters to clubs with upcoming events so the pill bar never shows a club pill that would yield an empty list. This avoids the confusion of tapping a pill and seeing nothing.
- `displayName(for:acronym:)` uses `clubAcronym` first since that's the cleanest short form. The word-skipping logic ("The", "UC", "UCD") catches common cases like "The Navigators" → "Navigators" and "UC Davis Pre-Med" → "Pre-Med".
- The purple accent on club pills is intentional — it visually separates "things you chose to follow" from "system filters", which subtly communicates that these are personal and removable.
- The `allEvents` property on `CampusViewModel` (the full unfiltered list) is what `activeSubscribedClubs` should scan — not the currently filtered `events` array.
