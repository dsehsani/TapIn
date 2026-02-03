# API Documentation

## Base URL

| Environment | URL |
|-------------|-----|
| **Local Development** | `http://localhost:8080` |
| **Production** | `https://your-app.appspot.com` |

## Authentication

**Current Status:** No authentication required (Milestone 0)

All endpoints are publicly accessible. Future versions may implement API key or token-based authentication.

---

## Endpoints

### Root

#### `GET /`

Returns API information and available endpoints.

**Response (200 OK):**

```json
{
    "service": "TapInApp Wordle Leaderboard API",
    "version": "1.0.0",
    "endpoints": {
        "submit_score": "POST /api/leaderboard/score",
        "get_leaderboard": "GET /api/leaderboard/<date>",
        "health_check": "GET /api/leaderboard/health"
    }
}
```

---

### Leaderboard

#### `POST /api/leaderboard/score`

Submit a Wordle game score to the leaderboard.

**Request Headers:**

| Header | Value |
|--------|-------|
| Content-Type | application/json |

**Request Body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `guesses` | integer | Yes | Number of guesses (1-6) |
| `time_seconds` | integer | Yes | Time to complete puzzle in seconds |
| `puzzle_date` | string | Yes | Puzzle date in YYYY-MM-DD format |

**Example Request:**

```bash
curl -X POST http://localhost:8080/api/leaderboard/score \
  -H "Content-Type: application/json" \
  -d '{
    "guesses": 4,
    "time_seconds": 120,
    "puzzle_date": "2026-02-02"
  }'
```

**Success Response (201 Created):**

```json
{
    "success": true,
    "score": {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "username": "SwiftFalcon",
        "guesses": 4,
        "time_seconds": 120,
        "puzzle_date": "2026-02-02"
    }
}
```

**Error Response (400 Bad Request):**

```json
{
    "success": false,
    "error": "Missing required field: guesses"
}
```

**Validation Rules:**

| Field | Rule |
|-------|------|
| `guesses` | Integer between 1 and 6 |
| `time_seconds` | Non-negative integer |
| `puzzle_date` | 10-character string in YYYY-MM-DD format |

---

#### `GET /api/leaderboard/<puzzle_date>`

Retrieve the leaderboard for a specific puzzle date.

**URL Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `puzzle_date` | string | Date in YYYY-MM-DD format |

**Query Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `limit` | integer | 5 | Max entries to return (1-10) |

**Example Request:**

```bash
# Get top 5 (default)
curl http://localhost:8080/api/leaderboard/2026-02-02

# Get top 3
curl http://localhost:8080/api/leaderboard/2026-02-02?limit=3
```

**Success Response (200 OK):**

```json
{
    "success": true,
    "puzzle_date": "2026-02-02",
    "leaderboard": [
        {
            "rank": 1,
            "username": "SwiftFalcon",
            "guesses": 3,
            "guesses_display": "🟩🟩🟩",
            "time_seconds": 95
        },
        {
            "rank": 2,
            "username": "BraveOtter",
            "guesses": 4,
            "guesses_display": "🟩🟩🟩🟩",
            "time_seconds": 120
        },
        {
            "rank": 3,
            "username": "CleverWolf",
            "guesses": 4,
            "guesses_display": "🟩🟩🟩🟩",
            "time_seconds": 145
        }
    ]
}
```

**Empty Leaderboard Response (200 OK):**

```json
{
    "success": true,
    "puzzle_date": "2026-02-02",
    "leaderboard": []
}
```

**Error Response (400 Bad Request):**

```json
{
    "success": false,
    "error": "Invalid date format. Use YYYY-MM-DD"
}
```

**Ranking Algorithm:**

1. **Primary sort:** Fewer guesses is better (ascending)
2. **Tiebreaker:** Faster time is better (ascending)

---

#### `GET /api/leaderboard/health`

Health check endpoint for monitoring service availability.

**Example Request:**

```bash
curl http://localhost:8080/api/leaderboard/health
```

**Response (200 OK):**

```json
{
    "status": "healthy",
    "service": "wordle-leaderboard"
}
```

---

## Response Formats

### Success Response

All successful responses include:

```json
{
    "success": true,
    // ... additional data
}
```

### Error Response

All error responses include:

```json
{
    "success": false,
    "error": "Human-readable error message"
}
```

---

## HTTP Status Codes

| Code | Description |
|------|-------------|
| `200` | Success |
| `201` | Created (score submitted) |
| `400` | Bad Request (validation error) |
| `404` | Not Found |
| `405` | Method Not Allowed |
| `500` | Internal Server Error |

---

## Data Types

### Score Object

Returned when submitting a score:

```json
{
    "id": "string (UUID)",
    "username": "string (Adjective+Noun)",
    "guesses": "integer (1-6)",
    "time_seconds": "integer",
    "puzzle_date": "string (YYYY-MM-DD)"
}
```

### LeaderboardEntry Object

Returned in leaderboard responses:

```json
{
    "rank": "integer (1-10)",
    "username": "string",
    "guesses": "integer (1-6)",
    "guesses_display": "string (emoji: 🟩🟩🟩)",
    "time_seconds": "integer"
}
```

---

## iOS Client Integration

### LeaderboardService Usage

```swift
// Submit a score
let response = try await LeaderboardService.shared.submitScore(
    guesses: 4,
    timeSeconds: 120,
    puzzleDate: "2026-02-02"
)

// Fetch leaderboard
let entries = try await LeaderboardService.shared.fetchLeaderboard(
    for: "2026-02-02",
    limit: 5
)

// Health check
let isHealthy = await LeaderboardService.shared.isServerHealthy()
```

---

## Rate Limiting

**Current Status:** No rate limiting (Milestone 0)

Future versions may implement rate limiting to prevent abuse.

---

## CORS

The API accepts requests from any origin during development:

```
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, POST, OPTIONS
Access-Control-Allow-Headers: Content-Type
```

Production deployments should restrict origins to the app's domain.
