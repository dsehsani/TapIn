# TapIn — Events Filter Cleanup

## Overview

The Events tab currently has four filter pills: `For You · All Events · UC Davis · Club Events`.

- **UC Davis** is always empty — the current data source (Aggie Life) provides no events that pass the `isOfficial` check reliably.
- **Club Events** is redundant with **All Events** since essentially every event in the feed has an organizer.

**After this change the pill bar looks like:**

```
For You · All Events
```

With one smart addition: **UC Davis appears automatically** as a third pill the moment there are any official UC Davis events in the feed — no manual toggle needed. Right now it stays hidden. When a future data source is added, it shows up for free.

**For You is also capped at 5 events** max — it should feel curated, not like another long list.

---

## Files to Modify

- `TapInApp/Models/CampusEvent.swift` — update `EventFilterType`
- `TapInApp/ViewModels/CampusViewModel.swift` — update filter logic + add UC Davis visibility computed property
- `TapInApp/Views/CampusView.swift` — render pills dynamically, hide UC Davis when empty
- `TapInApp/Services/ForYouFeedEngine.swift` — cap For You events at 5

---

## Change 1: `CampusEvent.swift` — Update `EventFilterType`

Remove `.studentPosted` ("Club Events"). Keep `.official` ("UC Davis") in the enum — it still needs to exist for the dynamic pill logic — but it will no longer appear in `allCases` for the pill bar.

```swift
// Replace the existing enum:
enum EventFilterType: String, CaseIterable {
    case forYou = "For You"
    case all    = "All Events"
    case official = "UC Davis"

    // NOTE: .official is NOT driven by allCases in the pill bar.
    // CampusView renders it conditionally based on whether UC Davis
    // events actually exist in the feed. See CampusView.swift.
    static let permanentFilters: [EventFilterType] = [.forYou, .all]
}
```

> `.studentPosted` ("Club Events") is removed entirely. Delete it — no other code references it after this change.

---

## Change 2: `CampusViewModel.swift` — Filter Logic + UC Davis Visibility

### 2a. Remove the `.studentPosted` case from the filter switch

```swift
switch filterType {
case .all:
    events = upcoming
case .forYou:
    events = EventPreferenceEngine.shared.recommend(from: upcoming)
case .official:
    events = upcoming.filter { $0.isOfficial }
// .studentPosted case removed
}
```

### 2b. Add a computed property for UC Davis pill visibility

```swift
/// True when there is at least one official UC Davis event in the feed.
/// CampusView uses this to show/hide the UC Davis filter pill dynamically.
var hasUCDavisEvents: Bool {
    allEvents.contains { $0.isOfficial }
}
```

---

## Change 3: `CampusView.swift` — Dynamic Pill Bar

Replace the `ForEach(EventFilterType.allCases)` loop with an explicit list that:
- Always shows `For You` and `All Events`
- Shows `UC Davis` only when `viewModel.hasUCDavisEvents` is true

```swift
// Replace:
ForEach(EventFilterType.allCases, id: \.self) { filter in
    // ...
}

// With:
let visibleFilters: [EventFilterType] = EventFilterType.permanentFilters
    + (viewModel.hasUCDavisEvents ? [.official] : [])

ForEach(visibleFilters, id: \.self) { filter in
    Button(action: {
        if filter == .forYou {
            viewModel.setProfileEvents(savedViewModel.savedEvents)
        }
        viewModel.filterEvents(by: filter)
    }) {
        HStack(spacing: 4) {
            if filter == .forYou {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .medium))
            }
            Text(filter.rawValue)
        }
        // ... existing pill styling unchanged ...
    }
}
```

### Also: guard against stale `filterType` on load

If `filterType` is somehow set to `.official` when UC Davis events aren't present (e.g. between app launches), reset it:

```swift
// In CampusView .onAppear or in CampusViewModel.applyFilters():
if filterType == .official && !hasUCDavisEvents {
    filterType = .forYou
}
```

---

## Change 4: `ForYouFeedEngine.swift` — Cap For You at 5 Events

In the `recommend()` function, both branches of the scoring logic currently cap at `15`. Change both to `5`:

```swift
// Branch 1 (3+ interests):
let minCarouselSize = 5   // was 15

// Branch 2 (fewer than 3 interests):
.prefix(5)               // was 15
```

That's two numbers to change — one in each branch of the `if userInterests.count >= 3` block.

---

## Acceptance Criteria

- [ ] The pill bar shows exactly two pills: `For You` and `All Events`.
- [ ] The `UC Davis` pill does not appear (since the feed currently has no `isOfficial` events).
- [ ] `For You` returns a maximum of 5 events.
- [ ] `All Events` shows the full event list — unchanged behavior.
- [ ] No reference to "Club Events" or `.studentPosted` remains anywhere in the codebase.
- [ ] If `hasUCDavisEvents` returns true (testable by manually setting `isOfficial = true` on a sample event), the `UC Davis` pill appears between `All Events` and nothing — it slots in automatically.
- [ ] Selecting `UC Davis` when it is visible correctly filters to `isOfficial == true` events only.
- [ ] If the app launches with `filterType == .official` stored and UC Davis events are empty, it resets to `.forYou` without crashing.
- [ ] The cold-start "Save events to personalize your feed" hint in `CampusView` still works correctly for `For You`.

---

## Notes for the Implementer

- `permanentFilters` is a static array on `EventFilterType` rather than overriding `allCases` — this keeps `allCases` intact in case anything else iterates over it (analytics, etc.).
- The `5` cap in `ForYouFeedEngine` applies to events only. The article scoring and featured article logic in the same `recommend()` function are untouched.
- `hasUCDavisEvents` checks `allEvents` (the full unfiltered list), not the currently displayed `events` array — so it stays accurate regardless of the active time filter.
