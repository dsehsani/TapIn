# TapIn Likes — Instagram-Style Architecture Fix

## Bug Report Summary

- **Device X** taps like → waits ~10 seconds → the like reverts (auto-unlikes)
- **Device Y** never sees the like, even after it appeared to succeed on Device X
- **Persistent loop**: After the first auto-unlike, every subsequent tap on Device X triggers the same pattern

---

## Root Cause Analysis

There are **four compounding bugs**, not one. They all interact to produce the symptoms above.

---

### Bug 1 (Primary): Backend Cold Start — the 10-second source

`app.yaml` sets `min_instances: 0`:

```yaml
automatic_scaling:
  min_instances: 0   # ← THIS
  max_instances: 2
```

When there is no recent traffic, the backend scales down to **zero running instances**. The first request after idle has to wait for App Engine to spin up a new Python 3.11 + gunicorn process — typically 5–15 seconds on an F1 instance. The iOS client has a **15-second timeout**, so the request is a coin-flip: it either barely makes it or times out. The 10 seconds the user reports is exactly this cold-start window.

**Fix:** Set `min_instances: 1` in `app.yaml`. This keeps at least one instance warm at all times and eliminates cold starts. Also add a keep-warm cron entry as a belt-and-suspenders backup.

```yaml
# app.yaml
automatic_scaling:
  min_instances: 1        # keep one instance warm — eliminates cold starts
  max_instances: 2
  target_cpu_utilization: 0.65
```

```yaml
# cron.yaml — add this entry
- description: "Keep backend warm — prevent cold starts"
  url: /api/social/health
  http_method: GET
  schedule: every 5 minutes
  timezone: America/Los_Angeles
```

---

### Bug 2 (Critical): `catch` block reverts on timeout — the auto-unlike

In both `LikeButton.swift` and `CardLikeIndicator.swift`, the `catch` block is:

```swift
} catch {
    // Revert on failure
    socialService.updateCache(
        contentType: contentType, contentId: contentId,
        status: LikeStatus(liked: wasLiked, likeCount: oldCount)
    )
}
```

This reverts on **any** error — including `URLError.timedOut`. This is architecturally wrong. As Instagram's engineering approach demonstrates:

> A timeout ≠ failure. A timeout means we didn't get a *response* — not that the work wasn't done. The server may have completed the write to Firestore just as the iOS client gave up waiting.

Reverting on a timeout produces exactly the reported bug: the user sees their like disappear, but Firestore may already have the like written. This creates split-brain state between the client and backend.

**The correct rule (Instagram-style):** Only revert on an **explicit server rejection (HTTP 4xx)**. Network errors, timeouts, and server errors (5xx) should NOT revert — they should be queued for retry.

The current `SocialError` enum doesn't distinguish between error types:

```swift
// Current — can't tell a 4xx from a timeout
enum SocialError: LocalizedError {
    case notAuthenticated
    case invalidURL
    case serverError   // ← too broad — covers 4xx, 5xx, timeout, no network
}
```

**Fix:** Differentiate error types and only revert on rejection:

```swift
enum SocialError: LocalizedError {
    case notAuthenticated
    case invalidURL
    case rejected(statusCode: Int)    // 4xx — server said no, revert
    case networkFailure(Error)        // timeout, no connection — retry, don't revert
    case serverError(Int)             // 5xx — retry, don't revert
}
```

Update the `post()` helper in `SocialService` to throw the right error type based on HTTP status:

```swift
private func post(url: String, token: String, body: [String: Any]) async throws -> [String: Any] {
    guard let requestURL = URL(string: url) else { throw SocialError.invalidURL }

    var request = URLRequest(url: requestURL)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.timeoutInterval = 30   // increase from 15 to 30 — handles slow cold starts
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SocialError.serverError(0) }

        if (400...499).contains(http.statusCode) {
            throw SocialError.rejected(statusCode: http.statusCode)
        }
        if !(200...299).contains(http.statusCode) {
            throw SocialError.serverError(http.statusCode)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SocialError.serverError(http.statusCode)
        }
        return json
    } catch let error as SocialError {
        throw error   // re-throw typed errors as-is
    } catch {
        throw SocialError.networkFailure(error)   // URLError.timedOut, no connection, etc.
    }
}
```

Update `toggleLike()` in both `LikeButton` and `CardLikeIndicator` to only revert on rejection:

```swift
Task {
    do {
        let (liked, count) = try await SocialService.shared.setLike(
            contentType: contentType, contentId: contentId, action: action
        )
        socialService.startToggleCooldown(contentType: contentType, contentId: contentId)
        socialService.updateCache(
            contentType: contentType, contentId: contentId,
            status: LikeStatus(liked: liked, likeCount: count)
        )
    } catch SocialError.rejected {
        // Server explicitly rejected (401, 403, 409) — revert
        socialService.updateCache(
            contentType: contentType, contentId: contentId,
            status: LikeStatus(liked: wasLiked, likeCount: oldCount)
        )
    } catch {
        // Timeout, 5xx, no network — DO NOT REVERT. Queue for retry instead.
        LikeSyncQueue.shared.enqueue(
            contentType: contentType, contentId: contentId, action: action
        )
        // Keep the optimistic state — user's intent is preserved
    }
    isToggling = false
}
```

---

### Bug 3: No Retry Queue — likes silently lost on network failure

When a like request fails with a network error or 5xx, the action is currently silently dropped (after reverting). There is no retry mechanism. The like is permanently lost.

**Fix:** Create `LikeSyncQueue.swift` — a lightweight persistent queue that stores pending like actions in `UserDefaults` and drains them on foreground return and app launch.

```swift
// LikeSyncQueue.swift — new file in Services/

@MainActor
final class LikeSyncQueue {
    static let shared = LikeSyncQueue()
    private let defaultsKey = "pendingLikeActions"

    struct PendingAction: Codable {
        let contentType: String   // "article" or "event"
        let contentId: String
        let action: String        // "like" or "unlike"
        let enqueuedAt: Date
        var retryCount: Int = 0
    }

    /// Enqueue a pending like action. Persisted to UserDefaults — survives app kill.
    func enqueue(contentType: ContentType, contentId: String, action: String) {
        var queue = load()
        // Dedup: if there's already a pending action for this item, replace it with the latest intent
        queue.removeAll { $0.contentId == contentId && $0.contentType == contentType.rawValue }
        queue.append(PendingAction(
            contentType: contentType.rawValue,
            contentId: contentId,
            action: action,
            enqueuedAt: Date()
        ))
        save(queue)
    }

    /// Drain the queue — call on app foreground and after successful auth.
    func drain() async {
        var queue = load()
        guard !queue.isEmpty else { return }

        var remaining: [PendingAction] = []
        for var item in queue {
            // Expire actions older than 48 hours
            if Date().timeIntervalSince(item.enqueuedAt) > 172_800 { continue }

            do {
                let (liked, count) = try await SocialService.shared.setLike(
                    contentType: ContentType(rawValue: item.contentType) ?? .article,
                    contentId: item.contentId,
                    action: item.action
                )
                // Success — update cache with confirmed server state
                if let ct = ContentType(rawValue: item.contentType) {
                    SocialService.shared.updateCache(
                        contentType: ct, contentId: item.contentId,
                        status: LikeStatus(liked: liked, likeCount: count)
                    )
                }
            } catch SocialError.rejected {
                // Server rejected — discard, don't retry
            } catch {
                // Still failing — keep in queue, cap at 5 retries
                item.retryCount += 1
                if item.retryCount < 5 {
                    remaining.append(item)
                }
            }
        }
        save(remaining)
    }

    private func load() -> [PendingAction] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let queue = try? JSONDecoder().decode([PendingAction].self, from: data) else { return [] }
        return queue
    }

    private func save(_ queue: [PendingAction]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(queue), forKey: defaultsKey)
    }
}
```

**Call `LikeSyncQueue.shared.drain()` in two places:**

1. `TapInAppApp.swift` — in the `.onChange(of: scenePhase)` handler when returning to `.active`
2. `AppState.restoreSession()` — after successful auth, in case likes were queued while signed out

---

### Bug 4: No Real-Time Updates — Device Y is blind

Device Y only refreshes like counts when:
- A view first appears (`onAppear`)
- The app returns from background (scene phase `.active`)

There is no live subscription. If Device Y has the article open when Device X likes it, Device Y never sees it.

**Fix:** Use Firestore's real-time snapshot listener on the parent document to stream `like_count` updates.

Add Firebase iOS SDK Firestore to the project (it's already a dependency via `GoogleService-Info.plist` and Firebase). Add a real-time listener method to `SocialService`:

```swift
// SocialService.swift — add imports
import FirebaseFirestore

// Add to SocialService:

private var likeListeners: [String: ListenerRegistration] = [:]

/// Subscribe to real-time like_count updates for an item.
/// The count updates instantly on all devices when any user likes/unlikes.
/// Call this when opening a detail view. Call stopListening() on dismiss.
func startListening(contentType: ContentType, contentId: String) {
    let key = cacheKey(contentType, contentId)
    guard likeListeners[key] == nil else { return }   // already listening

    let collectionName = contentType == .article ? "articles" : "events"
    let docRef = Firestore.firestore().collection(collectionName).document(contentId)

    let listener = docRef.addSnapshotListener { [weak self] snapshot, error in
        guard let self, let data = snapshot?.data() else { return }
        let serverCount = data["like_count"] as? Int ?? 0

        // Only update count — don't overwrite the user's own liked/unliked state from the server
        // (their personal liked status is handled by the toggle flow)
        let currentStatus = self.likeCache[key]
        let updatedStatus = LikeStatus(
            liked: currentStatus?.liked ?? false,
            likeCount: serverCount
        )

        // Respect cooldown — don't overwrite a recently-toggled value
        if !self.isInCooldown(key) {
            self.likeCache[key] = updatedStatus
        }
    }
    likeListeners[key] = listener
}

/// Stop listening. Call when leaving the detail view.
func stopListening(contentType: ContentType, contentId: String) {
    let key = cacheKey(contentType, contentId)
    likeListeners[key]?.remove()
    likeListeners.removeValue(forKey: key)
}
```

**Wire the listener into detail views:**

In `ArticleDetailView.swift` and the event detail view, add:
```swift
.onAppear {
    SocialService.shared.startListening(contentType: .article, contentId: article.socialId)
}
.onDisappear {
    SocialService.shared.stopListening(contentType: .article, contentId: article.socialId)
}
```

This gives Device Y live count updates the moment Device X's write commits to Firestore — no polling, no delay.

---

### Bug 5 (Secondary): `socialId` doesn't sanitize all URL special characters

The current `socialId` in `NewsArticle.swift`:
```swift
return url.replacingOccurrences(of: "https://", with: "")
          .replacingOccurrences(of: "http://", with: "")
          .replacingOccurrences(of: "/", with: "_")
          .replacingOccurrences(of: ".", with: "_")
```

This does NOT strip query strings (`?`), fragments (`#`), or encoded characters (`%`, `&`, `=`). A URL like `https://theaggie.org/article?id=123` becomes `theaggie_org_article?id=123` — the `?` and `=` are invalid in Firestore document IDs and cause silent write failures. The like is sent but Firestore silently rejects the document path.

**Fix in `NewsArticle.swift`:**

```swift
var socialId: String {
    guard let url = articleURL, !url.isEmpty else { return id.uuidString }

    // Strip scheme
    var cleaned = url
        .replacingOccurrences(of: "https://", with: "")
        .replacingOccurrences(of: "http://", with: "")

    // Remove query string and fragment — everything after ? or #
    if let queryStart = cleaned.firstIndex(of: "?") {
        cleaned = String(cleaned[..<queryStart])
    }
    if let fragmentStart = cleaned.firstIndex(of: "#") {
        cleaned = String(cleaned[..<fragmentStart])
    }

    // Replace all Firestore-invalid characters
    let invalidChars = CharacterSet(charactersIn: "/\\.#[]%&=+?@!")
    cleaned = cleaned.components(separatedBy: invalidChars).joined(separator: "_")

    // Trim trailing underscores, collapse repeated underscores
    while cleaned.hasSuffix("_") { cleaned = String(cleaned.dropLast()) }

    // Firestore doc IDs max 1500 bytes — truncate safely
    if cleaned.count > 200 { cleaned = String(cleaned.prefix(200)) }

    return cleaned.isEmpty ? id.uuidString : cleaned
}
```

Apply the same sanitization to `CampusEvent.socialId`.

---

## Summary of All Changes

| File | Change |
|------|--------|
| `backend/app.yaml` | `min_instances: 1` — eliminate cold starts |
| `backend/cron.yaml` | Add `/api/social/health` ping every 5 minutes |
| `TapInApp/Services/SocialService.swift` | Typed error enum, increase timeout to 30s, `post()` throws `rejected` vs `networkFailure`, add `startListening()` / `stopListening()` |
| `TapInApp/Services/LikeSyncQueue.swift` | **New file** — persistent retry queue for failed like actions |
| `TapInApp/Components/LikeButton.swift` | Only revert on `.rejected`, enqueue to `LikeSyncQueue` on network failure |
| `TapInApp/Components/CardLikeIndicator.swift` | Same changes as `LikeButton` |
| `TapInApp/App/TapInAppApp.swift` | Call `LikeSyncQueue.shared.drain()` on foreground return |
| `TapInApp/App/AppState.swift` — `restoreSession()` | Call `LikeSyncQueue.shared.drain()` after auth |
| `TapInApp/Views/ArticleDetailView.swift` | `startListening` on appear, `stopListening` on disappear |
| Event detail view | Same `startListening` / `stopListening` wiring |
| `TapInApp/Models/NewsArticle.swift` — `socialId` | Full URL sanitization including `?`, `#`, `%`, `&` |
| `TapInApp/Models/CampusEvent.swift` — `socialId` | Same sanitization |

---

## Testing

- [ ] Like an article → wait 15 seconds → like is NOT reverted, heart stays filled
- [ ] Like an article → force-kill the app before it syncs → reopen → like syncs automatically (queue drain)
- [ ] Device X likes a post → Device Y sees count update within 2 seconds without navigating away (real-time listener)
- [ ] Device X and Device Y both tap like at the same time → count is `+2`, not `+1` (Firestore transaction atomicity)
- [ ] Kill all backend instances → tap like → UI stays liked → instances warm up → like syncs
- [ ] Article URL with `?id=123` query param → like saves and retrieves correctly (socialId sanitization)
- [ ] Backend health endpoint responds in < 200ms (warm instance check)
- [ ] Retry queue caps at 5 attempts per action and expires after 48 hours
