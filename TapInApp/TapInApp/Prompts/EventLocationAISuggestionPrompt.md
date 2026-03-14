# TapIn — Step 2: Web Search for Club Locations

## Overview

When Step 1 (description scanning) also fails to find a location, this step uses the club/organizer name to search the web for their typical meeting place — things like their ASUCD page, Linktree, or club website. Because this data comes from the open web and may be outdated, **every surface in the app must make it crystal clear this is unverified.**

This is about being useful while being honest. The goal is not to replace the missing data — it's to give users a starting point while making sure they know to verify it themselves.

---

## Core Design Rule: Transparency First

Every piece of web-searched location data **must** be visually distinct from confirmed locations at all times. There is no case where a web-searched location should look like a confirmed one. The display rules are:

| Location source | Card label | Detail view label | Map shown? |
|---|---|---|---|
| iCal feed (confirmed) | `📍 Wellman Hall` | `Location — Wellman Hall` | ✅ Yes |
| Step 1: description scan | `📍 CoHo · AI` | `Location — CoHo  · AI suggested` | ✅ Yes |
| Step 2: web search | `🔍 Usually: CoHo` | Yellow banner + location (see below) | ❌ No |

Web-searched locations **never** show a map. A map implies confidence. We don't have that.

---

## What Changes

### Files to Modify

**Backend:**
- `backend/services/claude_service.py` — add `search_club_location()`
- `backend/services/event_processor_service.py` — call it after Step 1 returns `None`

**iOS:**
- `TapInApp/Models/CampusEvent.swift` — add `webLocation: String?` and `webLocationSource: String?`
- `TapInApp/Views/EventDetailView.swift` — add the unverified location banner
- `TapInApp/Components/ForYouEventCard.swift` — show web location on cards with distinct styling

---

## Backend Changes

### 1. `claude_service.py` — Add `search_club_location()`

This method uses Claude's web search tool to look up where a club typically meets. It is only called when both the iCal location field and the description scan return nothing.

```python
def search_club_location(self, organizer_name: str, club_acronym: str | None = None) -> dict | None:
    """
    Uses Claude + web search to find where a club typically meets.
    Only called when iCal location == "TBD" AND description scan found nothing.

    Args:
        organizer_name: The club or organizer name from the iCal feed.
        club_acronym:   Optional short club code (e.g. "ASUCD", "AIChE").

    Returns:
        dict with keys: { "location": str, "source": str } on success,
        or None if nothing credible is found.

        "source" is a short label for what was found, e.g.:
            "ASUCD page", "club website", "Linktree"
        This is shown to users so they know where to verify.
    """
    if not organizer_name or not organizer_name.strip():
        return None

    cache_key = f"webloc_{organizer_name}_{club_acronym or ''}"
    cached = self._web_location_cache.get(cache_key)
    if cached is not None:
        import json
        try:
            return json.loads(cached) if cached != "__NONE__" else None
        except Exception:
            return None

    search_query = f'"{organizer_name}" UC Davis meeting location'
    if club_acronym:
        search_query = f'"{organizer_name}" OR "{club_acronym}" UC Davis club meeting location'

    system_prompt = (
        "You are a research assistant helping a UC Davis campus events app. "
        "Use your web search tool to find where a UC Davis student club typically holds its meetings or events. "
        "Look at their ASUCD page, club website, Linktree, or Instagram bio. "
        "Return a JSON object with exactly two keys: "
        '  "location": a short venue name (e.g. "Wellman Hall", "CoHo", "Zoom"), '
        '  "source": a short label for where you found it (e.g. "ASUCD page", "club website", "Linktree"). '
        'If you cannot find a credible, specific location, return exactly: {"location": null, "source": null}. '
        "Never guess or hallucinate. Only return a location you actually found in a source."
    )

    try:
        client = self._get_client()

        # Use claude-sonnet with web search tool for this task
        message = client.messages.create(
            model="claude-sonnet-4-5-20250929",
            max_tokens=120,
            system=system_prompt,
            tools=[{"type": "web_search_20250305", "name": "web_search", "max_uses": 2}],
            messages=[
                {
                    "role": "user",
                    "content": f"Find where this UC Davis club usually meets: {organizer_name}"
                               + (f" (acronym: {club_acronym})" if club_acronym else "")
                }
            ]
        )

        # Extract the final text response from the message
        raw = ""
        for block in message.content:
            if hasattr(block, "text"):
                raw = block.text.strip()
                break

        if not raw:
            self._web_location_cache.set(cache_key, "__NONE__")
            return None

        import json, re
        # Pull the JSON object out of the response (Claude may wrap it in prose)
        json_match = re.search(r'\{.*?\}', raw, re.DOTALL)
        if not json_match:
            self._web_location_cache.set(cache_key, "__NONE__")
            return None

        result = json.loads(json_match.group())
        location = result.get("location")
        source = result.get("source")

        if not location or location == "null":
            self._web_location_cache.set(cache_key, "__NONE__")
            return None

        # Sanity check: reject anything suspiciously long
        if len(location) > 80:
            self._web_location_cache.set(cache_key, "__NONE__")
            return None

        output = {"location": location, "source": source or "web"}
        self._web_location_cache.set(cache_key, json.dumps(output))
        return output

    except Exception:
        return None
```

**Add the cache instance** at the bottom of `claude_service.py`:

```python
claude_service = ClaudeService()
claude_service._bullet_cache = SummaryCache(max_size=500)
claude_service._location_cache = SummaryCache(max_size=500)
claude_service._web_location_cache = SummaryCache(max_size=500)   # ← add this line
```

---

### 2. `event_processor_service.py` — Call Web Search After Step 1 Fails

Extend the existing location block from Step 1. Only call `search_club_location()` when Step 1 returned `None` AND the event has an organizer name to search with.

```python
# ── Location enrichment pipeline ──────────────────────────────────────────────

if event.get("location", "TBD") not in ("TBD", "", None):
    # iCal gave us a real location — nothing to do
    event["aiLocation"] = None
    event["webLocation"] = None
    event["webLocationSource"] = None

else:
    # Step 1: scan the description
    inferred = claude_service.extract_location_from_description(title, description)

    if inferred:
        event["aiLocation"] = inferred
        event["webLocation"] = None
        event["webLocationSource"] = None

    else:
        # Step 2: web search for club meeting place
        event["aiLocation"] = None
        organizer = event.get("organizerName") or event.get("clubAcronym")
        if organizer:
            web_result = claude_service.search_club_location(
                organizer_name=event.get("organizerName", ""),
                club_acronym=event.get("clubAcronym")
            )
            if web_result:
                event["webLocation"] = web_result["location"]
                event["webLocationSource"] = web_result["source"]
            else:
                event["webLocation"] = None
                event["webLocationSource"] = None
        else:
            event["webLocation"] = None
            event["webLocationSource"] = None

# ─────────────────────────────────────────────────────────────────────────────
```

---

## iOS Changes

### 3. `CampusEvent.swift` — Add Two New Fields

```swift
let webLocation: String?        // Web-searched club meeting location (unverified)
let webLocationSource: String?  // Where it was found, e.g. "ASUCD page", "Linktree"
```

Add both to `CodingKeys`, `init(from decoder:)`, `encode(to encoder:)`, and the memberwise `init`.

#### Extend the computed properties from Step 1

```swift
extension CampusEvent {

    var displayLocation: String {
        if location != "TBD" && !location.isEmpty { return location }
        if let ai = aiLocation { return ai }
        if let web = webLocation { return web }
        return "TBD"
    }

    var isLocationInferred: Bool {
        return (location == "TBD" || location.isEmpty) && aiLocation != nil
    }

    /// True when the location came from a web search — least confident source.
    var isLocationFromWeb: Bool {
        return (location == "TBD" || location.isEmpty)
            && aiLocation == nil
            && webLocation != nil
    }
}
```

---

### 4. `EventDetailView.swift` — Unverified Location Banner

When `event.isLocationFromWeb` is true, **replace** the normal location row + map with a clearly styled warning banner. Do not attempt to geocode or show a map for web-searched locations.

```swift
// Replace the existing location block with this:

if event.location != "TBD" && !event.location.isEmpty {
    // ── Confirmed iCal location ──────────────────────────────────────
    DetailRow(
        icon: "mappin.circle.fill",
        title: "Location",
        value: event.location,
        colorScheme: colorScheme
    )
    if let coordinate = locationCoordinate {
        // existing map preview code — unchanged
    }

} else if event.isLocationInferred, let aiLoc = event.aiLocation {
    // ── Step 1: AI-extracted from description ────────────────────────
    DetailRow(
        icon: "mappin.circle.fill",
        title: "Location",
        value: aiLoc,
        colorScheme: colorScheme
    )
    // Append "· AI suggested" inline using a subtitle or HStack
    Text("AI suggested from event description")
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.top, -6)

    if let coordinate = locationCoordinate {
        // existing map preview code — unchanged
    }

} else if event.isLocationFromWeb, let webLoc = event.webLocation {
    // ── Step 2: Web-searched — show with explicit unverified warning ─
    UnverifiedLocationBanner(
        location: webLoc,
        source: event.webLocationSource ?? "web"
    )

} else {
    // ── No location at all ───────────────────────────────────────────
    DetailRow(
        icon: "mappin.circle.fill",
        title: "Location",
        value: "TBD",
        colorScheme: colorScheme
    )
}
```

#### `UnverifiedLocationBanner` — New Component

Create this as a private view inside `EventDetailView.swift` (or a new file `UnverifiedLocationBanner.swift` in `Components/`):

```swift
struct UnverifiedLocationBanner: View {
    let location: String
    let source: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // Header row — warning icon + label
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 13))
                Text("Unverified Location")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.yellow)
            }

            // The location itself
            HStack(spacing: 6) {
                Image(systemName: "mappin.slash")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                Text(location)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }

            // Source + disclaimer
            Text("Found on \(source). This is where the club typically meets — not confirmed for this specific event. Verify before heading over.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.yellow.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.yellow.opacity(0.35), lineWidth: 1)
                )
        )
    }
}
```

**No map is shown for web-sourced locations.** The banner replaces the entire location + map section.

---

### 5. `ForYouEventCard.swift` — Distinct Card Label for Web Locations

Update `hasRealLocation` and `shortenedLocation` to be aware of all three sources. Also update the location display block on the card.

```swift
// Replace the existing hasRealLocation computed property:
private var hasRealLocation: Bool {
    let loc = event.location
    if !loc.isEmpty && loc != "TBD" && loc != "N/A" { return true }
    if event.aiLocation != nil { return true }
    if event.webLocation != nil { return true }
    return false
}

// Replace the existing location HStack in the card body:
if hasRealLocation {
    if event.isLocationFromWeb, let webLoc = event.webLocation {
        // Web-sourced: search icon + muted styling to signal uncertainty
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10))
            Text("Usually: \(webLoc)")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(.secondary)          // muted, not bold primary color
        .lineLimit(1)

    } else {
        // Confirmed or AI-from-description: normal styling
        HStack(spacing: 4) {
            Image(systemName: "mappin")
                .font(.system(size: 11))
            Text(event.isLocationInferred ? (event.aiLocation ?? shortenedLocation) : shortenedLocation)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))
        .lineLimit(1)
    }
}
```

The card uses a **magnifying glass icon** and the prefix **"Usually:"** for web-sourced locations. The muted `.secondary` color (vs. the full primary color for confirmed locations) reinforces the difference at a glance without requiring the user to read the label.

---

## Acceptance Criteria

- [ ] Events with a confirmed iCal location are completely unaffected — no new fields shown, map works as before.
- [ ] Events resolved by Step 1 (description scan) show "AI suggested from event description" below the location, and the map still renders.
- [ ] Events resolved by Step 2 (web search) show `UnverifiedLocationBanner` — yellow border, warning icon, disclaimer text, source label. No map is rendered.
- [ ] Events with no location from any source still show "TBD".
- [ ] On the card, web-sourced locations display with a magnifying glass, "Usually: [location]", and muted secondary color — clearly different from confirmed locations.
- [ ] On the card, confirmed and AI-from-description locations display with the existing mappin icon and primary color — unchanged from today.
- [ ] `webLocation` and `webLocationSource` are `nil` for all events that already had a real iCal location. No extra Claude calls are made for those events.
- [ ] Web search only runs when `organizerName` or `clubAcronym` is non-nil. Events with no organizer info are left as TBD rather than making a fruitless search call.
- [ ] Results are cached in `_web_location_cache` so re-processing the same event makes no additional API call.
- [ ] The `UnverifiedLocationBanner` is never shown for Step 1 (description-scan) results — only for Step 2 (web search).

---

## Notes for the Implementer

- The **yellow banner** is intentional and distinct. It should look like a caution state — not an error (red) and not a normal info row (plain text). Users should feel like they're being given a helpful hint with a clear "heads up, verify this."
- The word **"Usually"** on the card is load-bearing. It signals habit/pattern, not confirmed fact, without requiring a full sentence.
- **Never geocode web-sourced locations.** Even if the location string happens to be a valid address, showing a map pin implies confirmed precision we don't have.
- The `source` field (e.g. "ASUCD page", "Linktree") is shown in the banner because it gives users a direct path to verify. If a user sees "Found on Linktree" they know exactly where to go to check.
- `max_uses: 2` on the web search tool is intentional. One search usually suffices; two allows a follow-up if the first result is thin. More than two would be excessive for this use case and adds latency to the pipeline.
- Keep an eye on pipeline runtime — web search adds real latency (1–3s per event). Consider adding a timeout wrapper around `search_club_location()` so a slow search doesn't hold up the rest of the batch.
