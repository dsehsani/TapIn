# TapIn Likes — Remaining Issues Fix Prompt

## Context

The core like architecture is solid: idempotent `setLike` with action parameter, typed `SocialError` for revert-vs-retry, `LikeSyncQueue` for persistence, Firestore real-time listeners on detail views, batch prefetch from feed view models, and cooldown-based merge in the shared cache. These all work.

The remaining issues are why cross-device feedback still feels slow and occasionally inconsistent between a physical phone and the iOS Simulator.

---

## Issue 1: `socialId` Does Not Sanitize URL Query Params or Special Characters

### Problem

`NewsArticle.socialId` strips `https://`, `http://`, and replaces `/` and `.` with `_`, but does **not** handle:
- Query strings: `?id=123&ref=home`
- Fragments: `#section-2`
- Percent-encoded chars: `%20`, `%3A`
- Other Firestore-invalid chars: `~`, `*`, `[`, `]`

A URL like `https://theaggie.org/article?id=123` becomes `theaggie_org_article?id=123`. The `?` and `=` either cause a silent Firestore write failure or create a different document than expected. Two devices parsing the same URL differently would see different like counts.

`CampusEvent.socialId` has a similar issue — it uses `title` directly, which can contain spaces, apostrophes, colons, parentheses, and other characters that are invalid in Firestore document IDs.

### File: `TapInApp/Models/NewsArticle.swift`

Replace the `socialId` computed property:

```swift
var socialId: String {
    guard let url = articleURL, !url.isEmpty else { return id.uuidString }

    var cleaned = url
        .replacingOccurrences(of: "https://", with: "")
        .replacingOccurrences(of: "http://", with: "")

    // Strip query string and fragment
    if let idx = cleaned.firstIndex(of: "?") { cleaned = String(cleaned[..<idx]) }
    if let idx = cleaned.firstIndex(of: "#") { cleaned = String(cleaned[..<idx]) }

    // Strip trailing slashes
    while cleaned.hasSuffix("/") { cleaned = String(cleaned.dropLast()) }

    // Replace all characters that are invalid or unsafe in Firestore document IDs
    // Valid: alphanumerics, hyphens, underscores
    cleaned = cleaned.unicodeScalars.map { scalar in
        CharacterSet.alphanumerics.contains(scalar) || scalar == "-" || scalar == "_"
            ? String(scalar)
            : "_"
    }.joined()

    // Collapse repeated underscores
    while cleaned.contains("__") {
        cleaned = cleaned.replacingOccurrences(of: "__", with: "_")
    }

    // Firestore doc IDs max 1500 bytes — cap at 200 for safety
    if cleaned.count > 200 { cleaned = String(cleaned.prefix(200)) }

    return cleaned.isEmpty ? id.uuidString : cleaned
}
```

### File: `TapInApp/Models/CampusEvent.swift`

Apply the same sanitization to `socialId`:

```swift
var socialId: String {
    let formatter = ISO8601DateFormatter()
    let raw = "\(title)_\(formatter.string(from: date))"

    let cleaned = raw.unicodeScalars.map { scalar in
        CharacterSet.alphanumerics.contains(scalar) || scalar == "-" || scalar == "_"
            ? String(scalar)
            : "_"
    }.joined()
    .replacingOccurrences(of: "__", with: "_")

    if cleaned.count > 200 { return String(cleaned.prefix(200)) }
    return cleaned.isEmpty ? id.uuidString : cleaned
}
```

### Important: Migration

If likes already exist in Firestore under the OLD `socialId` format, changing the format will orphan them (new format → new document path → old likes invisible). To handle this:

Option A (recommended): Check if `socialId` would actually change by comparing old vs new. If none of your current article URLs contain `?`, `#`, or other special chars, the output is identical and no migration is needed — the fix is purely protective.

Option B: If existing data uses the old format, add a one-time migration or keep a lookup table that maps old → new.

---

## Issue 2: `batch_like_status` Backend Is an N+1 Sequential Loop

### Problem

The backend `batch_like_status` method loops through items and calls `get_like_status` sequentially. Each `get_like_status` makes **2 Firestore reads** (parent doc + likes sub-doc). A feed with 15 articles = 30 serial Firestore reads. This takes 2–5 seconds depending on Firestore latency.

```python
# Current — sequential N+1
def batch_like_status(self, items: list[dict], user_id: str) -> dict:
    results = {}
    for item in items:
        # Each call does 2 Firestore reads — sequentially
        liked, count = self.get_like_status(ct, cid, user_id)
        results[key] = {"liked": liked, "like_count": count}
    return results
```

### File: `backend/repositories/social_repository.py`

Replace with a parallelized version using `getAll()` for batched reads:

```python
def batch_like_status(self, items: list[dict], user_id: str) -> dict:
    """
    Returns like status for multiple items using batched Firestore reads.
    Reads all parent docs and like sub-docs in two bulk operations instead of 2N sequential reads.
    """
    db = self._db()
    results = {}

    if not items:
        return results

    # Build all document references upfront
    parent_refs = []
    like_refs = []
    keys = []

    for item in items:
        ct = item["content_type"]
        cid = item["content_id"]
        key = f"{ct}_{cid}"
        keys.append(key)

        col_name = _content_collection(ct)
        parent_ref = db.collection(col_name).document(cid)
        like_ref = parent_ref.collection("likes").document(user_id)
        parent_refs.append(parent_ref)
        like_refs.append(like_ref)

    # Batch read all parent documents at once
    parent_snaps = db.get_all(parent_refs)
    parent_map = {}
    for snap in parent_snaps:
        parent_map[snap.id] = snap

    # Batch read all like sub-documents at once
    like_snaps = db.get_all(like_refs)
    like_map = {}
    for snap in like_snaps:
        # Build a compound key from the parent path to avoid ID collisions
        like_map[snap.reference.path] = snap

    # Assemble results
    for i, key in enumerate(keys):
        try:
            parent_snap = parent_map.get(parent_refs[i].id)
            like_count = 0
            if parent_snap and parent_snap.exists:
                like_count = (parent_snap.to_dict() or {}).get("like_count", 0)

            like_path = like_refs[i].path
            liked = like_map.get(like_path) is not None and like_map[like_path].exists

            results[key] = {"liked": liked, "like_count": like_count}
        except Exception as e:
            logger.error(f"batch_like_status error for {key}: {e}")
            results[key] = {"liked": False, "like_count": 0}

    return results
```

This turns 2N sequential reads into 2 batch reads (`get_all` for parents + `get_all` for likes). For 15 articles, this drops from ~30 sequential round-trips to 2 batched round-trips — roughly 5–10x faster.

---

## Issue 3: Firestore Listener Callback Dispatches to Main Actor Asynchronously

### Problem

`addSnapshotListener` fires its closure on a **background thread**. `SocialService` is `@MainActor` isolated, so accessing `self.likeCache` and `self.mergeStatus` from the closure triggers an implicit async dispatch to the main actor. This adds a small but noticeable delay — the update isn't processed until the main run loop ticks.

### File: `TapInApp/Services/SocialService.swift` — `startListening()`

Wrap the callback body in an explicit `Task { @MainActor in }` to make the dispatch explicit and ensure it happens immediately:

```swift
let listener = docRef.addSnapshotListener { [weak self] snapshot, error in
    guard let self else { return }
    guard let data = snapshot?.data() else { return }
    let serverCount = data["like_count"] as? Int ?? 0

    Task { @MainActor in
        let currentStatus = self.likeCache[key]
        let updatedStatus = LikeStatus(
            liked: currentStatus?.liked ?? false,
            likeCount: serverCount
        )
        self.mergeStatus(key: key, serverStatus: updatedStatus)
    }
}
```

This doesn't change behavior but makes the main-actor hop explicit, ensures it runs at high priority, and eliminates any compiler warnings about non-sendable captures.

---

## Issue 4: No Tap Debounce — Rapid Double-Taps Cause Flicker

### Problem

If the user double-taps the heart in quick succession, two `setLike` calls fire: one with `action: "like"`, then immediately another with `action: "unlike"`. The backend handles this safely (idempotent), but the optimistic UI flickers: liked → unliked → liked → unliked.

### File: `TapInApp/Components/LikeButton.swift` and `CardLikeIndicator.swift`

Add a simple `isToggling` debounce guard:

```swift
struct LikeButton: View {
    let contentType: ContentType
    let contentId: String

    @ObservedObject private var socialService = SocialService.shared
    @State private var isAnimating = false
    @State private var isToggling = false   // ← ADD THIS

    // ... body unchanged ...

    private func toggleLike() {
        guard !isToggling else { return }   // ← ADD THIS
        isToggling = true                   // ← ADD THIS

        let wasLiked = status.liked
        let oldCount = status.likeCount
        let newLiked = !wasLiked
        let newCount = max(0, oldCount + (newLiked ? 1 : -1))

        socialService.updateCache(
            contentType: contentType, contentId: contentId,
            status: LikeStatus(liked: newLiked, likeCount: newCount)
        )
        socialService.startToggleCooldown(contentType: contentType, contentId: contentId)

        withAnimation { isAnimating = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { isAnimating = false }

        let action = newLiked ? "like" : "unlike"
        Task {
            do {
                let (liked, count) = try await SocialService.shared.setLike(
                    contentType: contentType, contentId: contentId, action: action
                )
                socialService.updateCache(
                    contentType: contentType, contentId: contentId,
                    status: LikeStatus(liked: liked, likeCount: count)
                )
            } catch SocialError.rejected {
                socialService.updateCache(
                    contentType: contentType, contentId: contentId,
                    status: LikeStatus(liked: wasLiked, likeCount: oldCount)
                )
            } catch {
                LikeSyncQueue.shared.enqueue(
                    contentType: contentType, contentId: contentId, action: action
                )
            }
            isToggling = false   // ← ADD THIS — re-enable taps after server responds
        }
    }
}
```

Apply the same `isToggling` guard to `CardLikeIndicator.swift`.

This prevents the second tap from firing while the first is still in-flight. The button stays visually tappable (no opacity change) but silently ignores rapid taps until the current request resolves or fails.

---

## Issue 5: `refreshAllCachedLikes` Runs Sequentially After `LikeSyncQueue.drain`

### Problem

In `TapInAppApp.swift`, the foreground handler runs:
```swift
await LikeSyncQueue.shared.drain()          // waits for all pending retries
await SocialService.shared.refreshAllCachedLikes()  // then refreshes cache
```

These are sequential. If the drain has 3 pending items and the network is slow, `refreshAllCachedLikes` doesn't start until all retries finish. The user stares at stale counts.

### File: `TapInApp/App/TapInAppApp.swift`

Run them concurrently:

```swift
.onChange(of: scenePhase) { _, newPhase in
    if newPhase == .active && !isCheckingSession {
        Task {
            needsForceUpdate = await AppUpdateService.shared.isUpdateRequired()
            async let drain: Void = LikeSyncQueue.shared.drain()
            async let refresh: Void = SocialService.shared.refreshAllCachedLikes()
            _ = await (drain, refresh)
        }
    }
}
```

Now both run in parallel — the cache refreshes immediately while the retry queue drains in the background.

---

## Files to Modify

| File | Change |
|------|--------|
| `TapInApp/Models/NewsArticle.swift` — `socialId` | Full URL sanitization: strip query/fragment, allow only alphanumeric + hyphen + underscore |
| `TapInApp/Models/CampusEvent.swift` — `socialId` | Same sanitization for title + date |
| `backend/repositories/social_repository.py` — `batch_like_status` | Replace N+1 sequential loop with 2 batched `get_all()` calls |
| `TapInApp/Services/SocialService.swift` — `startListening` | Explicit `Task { @MainActor in }` in the snapshot callback |
| `TapInApp/Components/LikeButton.swift` | Add `@State private var isToggling` debounce guard |
| `TapInApp/Components/CardLikeIndicator.swift` | Same debounce guard |
| `TapInApp/App/TapInAppApp.swift` | Run `drain()` and `refreshAllCachedLikes()` concurrently with `async let` |

---

## Issue 6: `like_count` Uses Read-Then-Set Instead of Atomic Increment — Drift Risk

### Problem

The current `set_like` method in `social_repository.py` reads the current `like_count` from the parent document, computes `current_count + 1` (or `- 1`), and sets the new value. While this is wrapped in a Firestore transaction (which retries on contention), the `like_count` is a **manually tracked derived number**. If it ever drifts from reality — a partial write, a bug, a failed decrement — it stays wrong forever. Every future like/unlike builds on the incorrect base.

Instagram's approach uses **atomic server-side increments** — the operation doesn't need to know the current value. It just says "+1" or "-1". This is faster (no read required for the count) and self-correcting with a periodic reconciliation job.

The current approach also does more work per transaction than necessary: it reads both the parent doc AND the like sub-doc inside the transaction. The sub-doc read is needed for idempotency, but the parent doc read is only needed because we're doing read-then-set on the count.

### File: `backend/repositories/social_repository.py` — `set_like()`

Replace the read-then-set count update with `firestore.Increment`:

```python
def set_like(self, content_type: str, content_id: str, user_id: str, action: str) -> tuple[bool, int]:
    """
    Idempotent like/unlike (Instagram-style). Returns (is_liked, new_like_count).
    action must be "like" or "unlike".
    Sending "like" when already liked is a no-op (and vice versa).
    Uses a transaction for the like sub-doc (idempotency) and atomic Increment for the count.
    """
    db = self._db()
    col_name = _content_collection(content_type)
    parent_ref = db.collection(col_name).document(content_id)
    like_ref = parent_ref.collection("likes").document(user_id)
    want_liked = action == "like"

    @firestore.transactional
    def _set(transaction):
        like_snap = like_ref.get(transaction=transaction)
        already_liked = like_snap.exists

        if want_liked and not already_liked:
            # Create like + atomic increment
            transaction.set(like_ref, {
                "user_id": user_id,
                "liked_at": _now_iso(),
            })
            transaction.update(parent_ref, {
                "like_count": firestore.Increment(1)
            })
            return True
        elif not want_liked and already_liked:
            # Remove like + atomic decrement
            transaction.delete(like_ref)
            transaction.update(parent_ref, {
                "like_count": firestore.Increment(-1)
            })
            return False
        else:
            # Already in desired state — no-op
            return already_liked

    transaction = db.transaction()
    is_liked = _set(transaction)

    # Read the committed count AFTER the transaction (not inside it)
    # This avoids reading the parent doc inside the transaction just for the count.
    parent_snap = parent_ref.get()
    like_count = max(0, (parent_snap.to_dict() or {}).get("like_count", 0)) if parent_snap.exists else 0

    return is_liked, like_count
```

Key changes:
- **Inside the transaction**: only read the `like_ref` sub-doc (for idempotency). Use `firestore.Increment(1)` or `firestore.Increment(-1)` on the parent — no need to read the parent doc's current count.
- **After the transaction**: read the parent doc once to get the committed `like_count` for the API response. This read is outside the transaction so it doesn't add contention.
- `transaction.update()` (not `transaction.set()` with merge) is used for the increment. Note: `update()` requires the parent document to exist. If the parent doc might not exist yet (first like on a brand new article), guard with `transaction.set(parent_ref, {"like_count": firestore.Increment(1)}, merge=True)` instead.

**Safe version using `set` with `merge=True`** (handles case where parent doc doesn't exist):

```python
if want_liked and not already_liked:
    transaction.set(like_ref, {
        "user_id": user_id,
        "liked_at": _now_iso(),
    })
    transaction.set(parent_ref, {"like_count": firestore.Increment(1)}, merge=True)
    return True
elif not want_liked and already_liked:
    transaction.delete(like_ref)
    transaction.set(parent_ref, {"like_count": firestore.Increment(-1)}, merge=True)
    return False
```

### Also update `toggle_like()` (legacy method)

Apply the same `Increment` pattern to `toggle_like()` for consistency, in case any code path still calls it:

```python
def toggle_like(self, content_type: str, content_id: str, user_id: str) -> tuple[bool, int]:
    db = self._db()
    col_name = _content_collection(content_type)
    parent_ref = db.collection(col_name).document(content_id)
    like_ref = parent_ref.collection("likes").document(user_id)

    @firestore.transactional
    def _toggle(transaction):
        like_snap = like_ref.get(transaction=transaction)

        if like_snap.exists:
            transaction.delete(like_ref)
            transaction.set(parent_ref, {"like_count": firestore.Increment(-1)}, merge=True)
            return False
        else:
            transaction.set(like_ref, {"user_id": user_id, "liked_at": _now_iso()})
            transaction.set(parent_ref, {"like_count": firestore.Increment(1)}, merge=True)
            return True

    transaction = db.transaction()
    is_liked = _toggle(transaction)

    parent_snap = parent_ref.get()
    like_count = max(0, (parent_snap.to_dict() or {}).get("like_count", 0)) if parent_snap.exists else 0
    return is_liked, like_count
```

### Optional: Add a count reconciliation cron job

As a safety net, add a periodic job that recounts the actual `likes` sub-collection and corrects `like_count` if it has drifted. Run this daily or weekly:

```python
# backend/services/social_reconciler.py (new file)

def reconcile_like_counts():
    """
    Recount likes sub-collections and fix any drifted like_count values.
    Run as a cron job — not time-critical.
    """
    db = get_firestore_client()

    for collection_name in ["articles", "events"]:
        docs = db.collection(collection_name).stream()
        for doc in docs:
            likes_count = sum(1 for _ in doc.reference.collection("likes").stream())
            stored_count = (doc.to_dict() or {}).get("like_count", 0)
            if likes_count != stored_count:
                logger.warning(
                    f"Drift detected: {collection_name}/{doc.id} "
                    f"stored={stored_count} actual={likes_count}"
                )
                doc.reference.update({"like_count": likes_count})
```

Add a cron route in `app.py` or `social.py`:

```python
@social_bp.route("/reconcile-likes", methods=["POST"])
def reconcile_likes():
    """Cron-only: recount like_count for all articles and events."""
    from services.social_reconciler import reconcile_like_counts
    reconcile_like_counts()
    return jsonify({"status": "ok"}), 200
```

Add to `cron.yaml`:

```yaml
- description: "Reconcile like counts — fix any drift"
  url: /api/social/reconcile-likes
  http_method: POST
  schedule: every day 03:00
  timezone: America/Los_Angeles
```

---

## Updated Files to Modify

| File | Change |
|------|--------|
| `TapInApp/Models/NewsArticle.swift` — `socialId` | Full URL sanitization: strip query/fragment, allow only alphanumeric + hyphen + underscore |
| `TapInApp/Models/CampusEvent.swift` — `socialId` | Same sanitization for title + date |
| `backend/repositories/social_repository.py` — `set_like` | Replace read-then-set with `firestore.Increment(1)` / `firestore.Increment(-1)`, read count after transaction |
| `backend/repositories/social_repository.py` — `toggle_like` | Same `Increment` change for consistency |
| `backend/repositories/social_repository.py` — `batch_like_status` | Replace N+1 sequential loop with 2 batched `get_all()` calls |
| `backend/services/social_reconciler.py` | **New file** — daily cron that recounts `likes` sub-collections and fixes drifted `like_count` |
| `backend/cron.yaml` | Add `/api/social/reconcile-likes` daily at 3 AM |
| `TapInApp/Services/SocialService.swift` — `startListening` | Explicit `Task { @MainActor in }` in the snapshot callback |
| `TapInApp/Components/LikeButton.swift` | Add `@State private var isToggling` debounce guard |
| `TapInApp/Components/CardLikeIndicator.swift` | Same debounce guard |
| `TapInApp/App/TapInAppApp.swift` | Run `drain()` and `refreshAllCachedLikes()` concurrently with `async let` |

---

## Testing

- [ ] Article URL with `?id=123` or `#section` → like saves and retrieves correctly on both devices
- [ ] Feed with 15+ articles → batch like status returns in < 1 second (check network inspector)
- [ ] Like on phone → simulator detail view shows updated count within 2 seconds (Firestore listener)
- [ ] Double-tap heart rapidly → only one network request fires, no visual flicker
- [ ] Background app → return → like counts refresh immediately (not blocked by queue drain)
- [ ] Event with special chars in title (colon, parentheses, apostrophe) → like works cross-device
- [ ] Two devices like the same post at the exact same time → count = +2, not +1 (atomic Increment vs read-then-set)
- [ ] Manually set a wrong `like_count` in Firestore → reconciliation cron corrects it overnight
- [ ] Like a brand-new article that has no parent doc in Firestore yet → `merge=True` creates it with `like_count: 1`
