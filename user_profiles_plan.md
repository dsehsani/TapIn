# User Profiles — Implementation Plan

## Overview

This document covers the design and implementation of persistent user profiles for TapIn. Profiles store credentials, per-game statistics, saved articles, and event RSVPs. The plan covers the backend (Flask + Firestore), the new API layer, and the iOS client changes needed to consume it.

The goal of this phase is to **make all profile data available to read and update via the API**. Tracking logic (e.g. detecting when a game is solved, when an article is read) is left to a later phase.

---

## Storage Decision: Firestore for User Data

The content migration (articles, events) moved from Firestore to GCS because content is shared across all users and is best served as large cached JSON blobs.

User profiles are the opposite: **per-user, write-frequently, with lookup-by-identity needs**. Firestore is the right tool:

| Need | GCS | Firestore |
|------|-----|-----------|
| Look up user by username/email | No (no query API) | Yes |
| Atomic field increment (solve count) | No | Yes |
| Concurrent writes to different fields | Risky | Safe |
| Username uniqueness enforcement | Manual + fragile | Atomic transaction |

The existing `firestore_client.py` in the backend already handles Firestore init. User profiles will use a new `users` collection alongside it.

---

## Data Schema

### Firestore Collection: `users`

**Document ID:** `{user_id}` (UUID, generated at registration)

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "username": "aggiejan",
  "email": "jan@ucdavis.edu",
  "passwordHash": "$2b$12$...",
  "createdAt": "2026-02-19T12:00:00Z",
  "updatedAt": "2026-02-19T12:00:00Z",

  "gameStats": {
    "wordle": {
      "solveCount": 14,
      "bestGuesses": 2,
      "bestTimeSeconds": 38,
      "totalGuesses": 62,
      "totalTimeSeconds": 840
    },
    "echo": {
      "solveCount": 7,
      "bestScore": 490,
      "totalScore": 2940
    },
    "trivia": {
      "solveCount": 0,
      "bestScore": null
    },
    "crossword": {
      "solveCount": 3,
      "bestTimeSeconds": 142
    }
  },

  "savedArticles": [
    {
      "articleId": "abc123",
      "articleURL": "https://theaggie.org/2026/02/19/story/",
      "title": "UC Davis Researchers Discover...",
      "savedAt": "2026-02-19T14:30:00Z"
    }
  ],

  "readArticles": [
    {
      "articleId": "abc123",
      "readAt": "2026-02-19T14:28:00Z"
    }
  ],

  "eventRSVPs": [
    {
      "eventId": "bbbb...bbbb",
      "eventTitle": "Picnic Day 2026",
      "rsvpAt": "2026-02-19T10:00:00Z"
    }
  ]
}
```

### Field Notes

- **`passwordHash`** — bcrypt hash, never returned to the client.
- **`gameStats`** — one key per game type. Each game tracks what makes sense for it: Wordle tracks guess count and time, Echo tracks score, Crossword tracks time only. `null` fields mean "no data yet."
- **`savedArticles`** — full article metadata stored so the Saved tab can display without a separate fetch.
- **`readArticles`** — lightweight list of IDs + timestamps; no metadata needed.
- **`eventRSVPs`** — title stored alongside ID so the UI can display without re-fetching the events list.

---

## Firestore Indexes

Add to `firestore.indexes.json`:

```json
{
  "collectionGroup": "users",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "username", "order": "ASCENDING" },
    { "fieldPath": "email",    "order": "ASCENDING" }
  ]
}
```

Username and email must be unique. Enforced via Firestore transaction at registration (read → check → write atomically).

---

## Authentication

Passwords are hashed with **bcrypt** (via the `bcrypt` library). Sessions use **JWT tokens** (via `PyJWT`). The token is short-lived (7 days) and carries only the `user_id`.

```
Register → hash password → create user doc → return JWT
Login    → load user by username → verify hash → return JWT
All protected routes → parse JWT from Authorization header → inject user_id
```

---

## Backend Implementation

### New Files

```
tapin-backend/
├── repositories/
│   └── user_repository.py          # Firestore CRUD for user documents
├── services/
│   └── auth_service.py             # Password hash/verify + JWT encode/decode
├── api/
│   └── users.py                    # All /api/users/* endpoints
└── middleware/
    └── auth_middleware.py          # JWT verification decorator
```

### `repositories/user_repository.py`

Functions:
- `create_user(user_dict)` → atomic transaction: check username/email uniqueness, write doc
- `get_user_by_id(user_id)` → fetch by document ID
- `get_user_by_username(username)` → Firestore `where` query
- `get_user_by_email(email)` → Firestore `where` query
- `update_game_stats(user_id, game_type, stats_patch)` → Firestore `update` (partial, atomic)
- `add_saved_article(user_id, article_dict)` → `ArrayUnion` on `savedArticles`
- `remove_saved_article(user_id, article_id)` → filter + rewrite
- `add_read_article(user_id, article_dict)` → `ArrayUnion` on `readArticles`
- `add_event_rsvp(user_id, event_dict)` → `ArrayUnion` on `eventRSVPs`
- `remove_event_rsvp(user_id, event_id)` → filter + rewrite
- `delete_user(user_id)` → delete document

### `services/auth_service.py`

Functions:
- `hash_password(plain: str) -> str` → bcrypt hash
- `verify_password(plain: str, hashed: str) -> bool` → bcrypt check
- `create_token(user_id: str) -> str` → JWT with 7-day expiry
- `decode_token(token: str) -> str` → returns `user_id` or raises

### `middleware/auth_middleware.py`

Decorator `@require_auth` that:
1. Reads `Authorization: Bearer <token>` header
2. Calls `auth_service.decode_token()`
3. Sets `g.user_id` for the route handler
4. Returns 401 on missing or invalid token

---

## API Endpoints

All endpoints live under the `/api/users` blueprint.

### Authentication

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `POST` | `/api/users/register` | None | Create account, return JWT |
| `POST` | `/api/users/login` | None | Validate credentials, return JWT |

**POST /api/users/register**
```json
// Request
{
  "username": "aggiejan",
  "email": "jan@ucdavis.edu",
  "password": "hunter2"
}

// Response 201
{
  "success": true,
  "token": "<jwt>",
  "user": {
    "id": "550e8400...",
    "username": "aggiejan",
    "email": "jan@ucdavis.edu"
  }
}

// Error 409 — username or email already taken
{ "success": false, "error": "username_taken" }
```

**POST /api/users/login**
```json
// Request
{ "username": "aggiejan", "password": "hunter2" }

// Response 200
{ "success": true, "token": "<jwt>", "user": { "id": "...", "username": "aggiejan", "email": "..." } }

// Error 401
{ "success": false, "error": "invalid_credentials" }
```

---

### Profile

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `GET` | `/api/users/me` | Required | Fetch own full profile |
| `DELETE` | `/api/users/me` | Required | Delete account |

**GET /api/users/me** — returns the full profile document minus `passwordHash`.

---

### Game Stats

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `PATCH` | `/api/users/me/games/{game_type}` | Required | Update stats for one game |

`game_type` must be one of: `wordle`, `echo`, `trivia`, `crossword`.

**PATCH /api/users/me/games/wordle**
```json
// Request — all fields optional; only provided fields are updated
{
  "solveCount": 15,
  "bestGuesses": 2,
  "bestTimeSeconds": 38,
  "totalGuesses": 65,
  "totalTimeSeconds": 878
}

// Response 200
{ "success": true, "gameStats": { "wordle": { ... } } }
```

The endpoint accepts a **full stats replacement** for the given game type (not a diff). The iOS client is responsible for computing the new values before sending. This keeps the backend simple and stateless.

---

### Articles

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `GET` | `/api/users/me/articles/saved` | Required | List saved articles |
| `POST` | `/api/users/me/articles/saved` | Required | Save an article |
| `DELETE` | `/api/users/me/articles/saved/{article_id}` | Required | Unsave an article |
| `POST` | `/api/users/me/articles/read` | Required | Mark an article as read |
| `GET` | `/api/users/me/articles/read` | Required | List read article IDs |

**POST /api/users/me/articles/saved**
```json
// Request
{
  "articleId": "abc123",
  "articleURL": "https://theaggie.org/...",
  "title": "Story Title"
}

// Response 201
{ "success": true }
```

**POST /api/users/me/articles/read**
```json
// Request
{ "articleId": "abc123" }

// Response 201
{ "success": true }
```

---

### Events

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `GET` | `/api/users/me/events` | Required | List RSVPed events |
| `POST` | `/api/users/me/events` | Required | RSVP to an event |
| `DELETE` | `/api/users/me/events/{event_id}` | Required | Cancel RSVP |

**POST /api/users/me/events**
```json
// Request
{
  "eventId": "bbbb...bbbb",
  "eventTitle": "Picnic Day 2026"
}

// Response 201
{ "success": true }
```

---

## `requirements.txt` Additions

```
bcrypt>=4.1.0
PyJWT>=2.8.0
```

---

## iOS Changes

### `User.swift` — Expand the model

```swift
struct User: Identifiable, Codable {
    let id: UUID
    var username: String
    var email: String

    var gameStats: GameStatsMap
    var savedArticles: [SavedArticle]
    var readArticleIds: [String]
    var eventRSVPs: [EventRSVP]
}

struct GameStatsMap: Codable {
    var wordle: WordleStats
    var echo: EchoStats
    var trivia: TriviaStats
    var crossword: CrosswordStats
}

struct WordleStats: Codable {
    var solveCount: Int
    var bestGuesses: Int?
    var bestTimeSeconds: Int?
    var totalGuesses: Int
    var totalTimeSeconds: Int
}

struct EchoStats: Codable {
    var solveCount: Int
    var bestScore: Int?
    var totalScore: Int
}

struct TriviaStats: Codable {
    var solveCount: Int
    var bestScore: Int?
}

struct CrosswordStats: Codable {
    var solveCount: Int
    var bestTimeSeconds: Int?
}

struct SavedArticle: Codable, Identifiable {
    var id: String { articleId }
    let articleId: String
    let articleURL: String
    let title: String
    let savedAt: Date
}

struct EventRSVP: Codable, Identifiable {
    var id: String { eventId }
    let eventId: String
    let eventTitle: String
    let rsvpAt: Date
}
```

### `AuthService.swift` — Implement

The stub gets a full implementation:
- `register(username, email, password)` → stores JWT in Keychain
- `login(username, password)` → stores JWT in Keychain
- `logout()` → clears Keychain
- `currentUser` — published property, restored from Keychain on launch
- All calls inject `Authorization: Bearer <token>` via a shared `NetworkManager`

### `UserProfileService.swift` — New

Handles all `/api/users/me/*` endpoints:
- `fetchProfile()` → `GET /api/users/me`
- `updateGameStats(game, stats)` → `PATCH /api/users/me/games/{game}`
- `saveArticle(article)` → `POST /api/users/me/articles/saved`
- `unsaveArticle(id)` → `DELETE /api/users/me/articles/saved/{id}`
- `markRead(articleId)` → `POST /api/users/me/articles/read`
- `rsvpEvent(event)` → `POST /api/users/me/events`
- `cancelRsvp(eventId)` → `DELETE /api/users/me/events/{event_id}`

---

## Implementation Phases

### Phase 1 — Backend: Auth + Core Profile
1. Add `bcrypt` and `PyJWT` to `requirements.txt`
2. Create `services/auth_service.py`
3. Create `repositories/user_repository.py`
4. Create `middleware/auth_middleware.py`
5. Create `api/users.py` with register, login, and `GET /me`
6. Register blueprint in `app.py`

### Phase 2 — Backend: Game Stats + Articles + Events
1. Add game stats PATCH endpoint
2. Add saved/read article endpoints
3. Add event RSVP endpoints

### Phase 3 — iOS: Auth
1. Expand `User.swift` with new fields
2. Implement `AuthService.swift`
3. Wire login/register UI in `ProfileView.swift`
4. Store JWT in Keychain, inject into all API requests

### Phase 4 — iOS: Profile Data
1. Implement `UserProfileService.swift`
2. Update `SavedView.swift` to pull from profile instead of UserDefaults
3. Update `CampusView.swift` to use RSVP API
4. Update game ViewModels to call `updateGameStats` on completion

---

## Key Decisions Summary

| Decision | Choice | Reason |
|----------|--------|--------|
| Storage backend | Firestore | Per-user docs, username uniqueness, concurrent writes |
| Password hashing | bcrypt | Industry standard, salted |
| Session tokens | JWT (7-day) | Stateless, no server-side session store needed |
| Stats update model | Full replacement per game | Keeps backend simple; iOS owns the diff logic |
| Article metadata storage | Inline in profile | Avoids extra fetch when rendering Saved tab |
| Event title storage | Inline in RSVP | Same reason — display without re-fetching events |
