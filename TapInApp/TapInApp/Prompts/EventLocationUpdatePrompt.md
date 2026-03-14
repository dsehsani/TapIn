# TapIn — Step 1: AI Location Extraction from Event Descriptions

## Overview

Most events arrive from Aggie Life's iCal feed with no `LOCATION` field, so the parser correctly falls back to `"TBD"`. However, many organizers embed the venue directly in the event description — e.g. *"Join us at the CoHo!"* or *"Meet at Wellman Hall Room 26."* This feature teaches the backend AI pipeline to scan the description and extract a real location whenever one is present, before the event is stored in Firestore.

**Scope:** Backend pipeline + iOS display. No new API endpoints. No changes to the `CampusEvent` model's existing fields.

---

## What Changes

### Files to Modify

**Backend:**
- `backend/services/claude_service.py` — add `extract_location_from_description()`
- `backend/services/event_processor_service.py` — call extraction when `location == "TBD"`

**iOS:**
- `TapInApp/Models/CampusEvent.swift` — add `aiLocation: String?` field
- `TapInApp/Views/EventDetailView.swift` — display inferred location with a visual indicator
- `TapInApp/Components/ForYouEventCard.swift` — show inferred location on event cards

---

## Backend Changes

### 1. `claude_service.py` — Add `extract_location_from_description()`

Add this method to the `ClaudeService` class, alongside `summarize_event_internal` and `generate_bullet_points`. It uses the same internal (no rate-limit) pattern as the other pipeline methods.

```python
def extract_location_from_description(self, title: str, description: str) -> str | None:
    """
    Scans an event description for a venue or location mention.
    Called internally by the event processor when location == "TBD".

    Args:
        title: The event title (provides helpful context).
        description: The full event description text.

    Returns:
        A short location string (e.g. "CoHo", "Wellman Hall 26", "Zoom"),
        or None if no location is found in the text.
    """
    if not description or not description.strip():
        return None

    cache_key = f"loc_{title}\n{description}"
    cached = self._location_cache.get(cache_key)
    if cached is not None:
        return cached if cached != "__NONE__" else None

    system_prompt = (
        "You are a location extractor for a UC Davis campus events app. "
        "Your only job is to find a venue or location name mentioned in the event text. "
        "Return ONLY the location name — nothing else. No sentences, no punctuation. "
        "If the event is online, return 'Zoom' or the platform name. "
        "If no specific location is mentioned, return exactly: NONE"
    )

    user_prompt = (
        f"Event: {title}\n\n"
        f"{description}\n\n"
        "What is the location or venue for this event? "
        "Reply with ONLY the location name, or NONE if not mentioned."
    )

    try:
        client = self._get_client()
        message = client.messages.create(
            model="claude-haiku-4-5-20251001",   # fast + cheap — just extraction
            max_tokens=30,
            system=system_prompt,
            messages=[{"role": "user", "content": user_prompt}]
        )

        raw = message.content[0].text.strip()

        # Reject anything that looks like a failure or hallucination
        if not raw or raw.upper() == "NONE" or len(raw) > 80:
            self._location_cache.set(cache_key, "__NONE__")
            return None

        self._location_cache.set(cache_key, raw)
        return raw

    except Exception:
        return None
```

**Also add the cache instance** at the bottom of `claude_service.py` where the singleton is initialized:

```python
claude_service = ClaudeService()
claude_service._bullet_cache = SummaryCache(max_size=500)
claude_service._location_cache = SummaryCache(max_size=500)   # ← add this line
```

---

### 2. `event_processor_service.py` — Call Extraction in the Pipeline

Inside `_run_refresh()`, after generating `aiSummary` and `aiBulletPoints`, add the location extraction step. Only runs when the iCal feed gave us no location.

```python
# Generate AI summary (short sentence for card view)
event["aiSummary"] = claude_service.summarize_event_internal(description)

# Generate AI bullet points (for detail view)
event["aiBulletPoints"] = claude_service.generate_bullet_points(title, description)

# ── NEW: Extract location from description if iCal didn't provide one ─────────
if event.get("location", "TBD") in ("TBD", "", None):
    inferred = claude_service.extract_location_from_description(title, description)
    if inferred:
        event["aiLocation"] = inferred       # store alongside, NOT overwriting raw "location"
    else:
        event["aiLocation"] = None
else:
    event["aiLocation"] = None               # iCal location was real — no inference needed
# ─────────────────────────────────────────────────────────────────────────────
```

> **Important:** We write to `event["aiLocation"]`, **not** `event["location"]`. The original iCal location field stays untouched. The iOS app decides at display time which one to show.

---

## iOS Changes

### 3. `CampusEvent.swift` — Add `aiLocation` Field

Add one optional field to the model. No other fields change.

```swift
// Inside struct CampusEvent:
let aiLocation: String?          // ← AI-inferred location (only set when iCal location == "TBD")
```

Add `aiLocation` to `CodingKeys`:
```swift
case aiLocation
```

Add to `init(from decoder:)`:
```swift
aiLocation = try? c.decode(String.self, forKey: .aiLocation)
```

Add to `encode(to encoder:)`:
```swift
try c.encodeIfPresent(aiLocation, forKey: .aiLocation)
```

Add to the memberwise `init(...)`:
```swift
aiLocation: String? = nil,
// ...
self.aiLocation = aiLocation
```

#### Add a convenience computed property

```swift
extension CampusEvent {
    /// The best available location string for display.
    /// Returns the confirmed iCal location if present,
    /// the AI-inferred location if available, or "TBD" as a last resort.
    var displayLocation: String {
        if location != "TBD" && !location.isEmpty {
            return location
        }
        return aiLocation ?? "TBD"
    }

    /// True when the shown location was inferred by AI, not from the iCal feed.
    var isLocationInferred: Bool {
        return (location == "TBD" || location.isEmpty) && aiLocation != nil
    }
}
```

---

### 4. `EventDetailView.swift` — Show Inferred Location with an Indicator

Find where `event.location` is displayed in the detail view's header / location row. Replace `event.location` with `event.displayLocation` everywhere in this file.

Additionally, when `event.isLocationInferred` is true, append a small "AI suggested" label next to the location so users understand it's inferred, not confirmed by the organizer:

```swift
// In the location row (near the map preview / location label):
HStack(spacing: 4) {
    Text(event.displayLocation)
        .font(.subheadline)
        .foregroundColor(.primary)

    if event.isLocationInferred {
        Text("· AI suggested")
            .font(.caption2)
            .foregroundColor(.secondary)
    }
}
```

> This transparency is intentional — the reviewer's complaint was about *missing* locations, not about inaccurate ones. Labeling inferred locations lets users know they should still verify if it matters.

---

### 5. `ForYouEventCard.swift` — Use `displayLocation` on Cards

Find wherever `event.location` is shown on the card (the small location line, usually below the title). Replace with `event.displayLocation`.

No inference label is needed on the card — keep it clean. The label only appears in the full detail view where there's room.

---

## Acceptance Criteria

- [ ] Events where the iCal `LOCATION` field is present are **completely unaffected** — `aiLocation` is `nil`, `displayLocation` returns the original value, `isLocationInferred` is `false`.
- [ ] Events with `location == "TBD"` whose description mentions a venue now show that venue in the detail view and on the card.
- [ ] Events with `location == "TBD"` whose description does NOT mention a venue still show "TBD" — the model correctly returns `None`.
- [ ] Inferred locations are labeled "· AI suggested" in `EventDetailView`.
- [ ] Online/virtual events return `"Zoom"` or the correct platform name (e.g. `"Google Meet"`).
- [ ] No existing Firestore documents are corrupted — `aiLocation` is an optional field and defaults to `nil` for all legacy documents.
- [ ] The `extract_location_from_description` call uses `claude-haiku-4-5-20251001` (not Sonnet) to keep per-event pipeline cost low.
- [ ] Location extraction results are cached in `_location_cache` so re-processing the same event doesn't make a second API call.

---

## Notes for the Implementer

- Use `claude-haiku-4-5-20251001` for location extraction. It's fast, cheap, and the task is simple enough that Haiku handles it well. Sonnet is overkill here.
- The sentinel value `"__NONE__"` in the location cache prevents re-querying Claude for events whose descriptions genuinely don't mention a location. Without it, every pipeline refresh would re-call Claude for those events.
- The `max_tokens=30` cap is intentional — a location name should never be more than a few words. If Claude tries to return a full sentence, the `len(raw) > 80` guard will reject it.
- Do **not** geocode or validate the extracted location string on the backend. Leave geocoding to the existing `EventDetailView` logic that already handles `mapsQuery(for:)`.
- The `isLocationInferred` flag is also useful for future analytics — you can track how often AI fills in missing locations to measure the feature's real-world impact.
