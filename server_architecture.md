# Server Architecture

## Overview

The TapIn backend is a RESTful API server built with **Flask 3.0** (Python 3.11+). It provides the Wordle leaderboard functionality for the iOS app. The server follows a clean, modular architecture with separation between API routes, business logic, and data models.

## Tech Stack

| Component | Technology |
|-----------|------------|
| **Framework** | Flask 3.0 |
| **Language** | Python 3.11+ |
| **CORS** | Flask-CORS 4.0 |
| **WSGI Server** | Gunicorn 21.2 |
| **Deployment** | Google App Engine |
| **Storage** | In-memory (Milestone 0) |

## Directory Structure

```
wordle-leaderboard-server/
├── app.py                        # Flask application factory
├── models.py                     # Data models (dataclasses)
├── requirements.txt              # Python dependencies
├── app.yaml                      # Google App Engine config
│
├── api/
│   ├── __init__.py
│   └── leaderboard.py           # Leaderboard API endpoints
│
└── services/
    ├── __init__.py
    └── leaderboard_service.py   # Business logic layer
```

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      iOS Client                             │
│                   (TapInApp)                                │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ HTTP/HTTPS
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Flask Application                        │
│                       (app.py)                              │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                   CORS Middleware                     │  │
│  └───────────────────────────────────────────────────────┘  │
│                              │                              │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              API Blueprint (api/)                     │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │           leaderboard.py                        │  │  │
│  │  │  - POST /api/leaderboard/score                  │  │  │
│  │  │  - GET  /api/leaderboard/<date>                 │  │  │
│  │  │  - GET  /api/leaderboard/health                 │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
│                              │                              │
│  ┌───────────────────────────────────────────────────────┐  │
│  │            Service Layer (services/)                  │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │        leaderboard_service.py                   │  │  │
│  │  │  - Score submission                             │  │  │
│  │  │  - Leaderboard ranking                          │  │  │
│  │  │  - Username generation                          │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
│                              │                              │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              Data Layer (models.py)                   │  │
│  │  - Score (dataclass)                                  │  │
│  │  - LeaderboardEntry (dataclass)                       │  │
│  └───────────────────────────────────────────────────────┘  │
│                              │                              │
│  ┌───────────────────────────────────────────────────────┐  │
│  │               Storage (In-Memory)                     │  │
│  │           Dict[puzzle_date, List[Score]]              │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Design Patterns

| Pattern | Implementation |
|---------|----------------|
| **Application Factory** | `create_app()` in `app.py` |
| **Blueprint** | Modular API routing in `api/` |
| **Singleton** | `leaderboard_service` instance |
| **Repository** | Service layer abstracts storage |

## Data Models

### Score

Represents a submitted game score:

```python
@dataclass
class Score:
    id: str              # UUID, auto-generated
    username: str        # e.g., "SwiftFalcon"
    guesses: int         # 1-6
    time_seconds: int    # Completion time
    puzzle_date: str     # "YYYY-MM-DD"
```

### LeaderboardEntry

Display model for leaderboard responses:

```python
@dataclass
class LeaderboardEntry:
    rank: int            # Position (1-10)
    username: str        # Player name
    guesses: int         # Number of guesses
    guesses_display: str # Emoji display (e.g., "🟩🟩🟩")
    time_seconds: int    # Completion time
```

## Service Layer

### LeaderboardService

The `LeaderboardService` class encapsulates all business logic:

```python
class LeaderboardService:
    def __init__(self):
        self._scores: Dict[str, List[Score]] = {}

    def generate_username(self) -> str
    def submit_score(guesses, time_seconds, puzzle_date, username=None) -> Score
    def get_leaderboard(puzzle_date, limit=5) -> List[LeaderboardEntry]
    def get_all_dates() -> List[str]
    def clear_scores(puzzle_date=None) -> None
```

### Username Generation

Generates random anonymous usernames using Adjective+Noun combinations:

- **Adjectives (25):** Swift, Brave, Clever, Mighty, Noble, Bold, Quick, Sharp, Bright, Keen, Agile, Fierce, Lucky, Calm, Wise, Golden, Silver, Cosmic, Epic, Grand, Royal, Mystic, Ancient, Stellar, Thunder
- **Nouns (25):** Falcon, Otter, Wolf, Eagle, Bear, Tiger, Lion, Hawk, Fox, Deer, Panda, Koala, Shark, Dragon, Phoenix, Mustang, Aggie, Knight, Warrior, Champion, Legend, Pioneer, Voyager, Ranger, Scout

Example outputs: "SwiftFalcon", "BraveAggie", "CosmicDragon"

### Ranking Algorithm

Leaderboard entries are sorted by:
1. **Primary:** Fewer guesses (ascending)
2. **Secondary:** Faster time as tiebreaker (ascending)

```python
sorted_scores = sorted(
    scores,
    key=lambda s: (s.guesses, s.time_seconds)
)
```

## Storage

### Current (Milestone 0)

In-memory dictionary storage:

```python
_scores: Dict[str, List[Score]] = {
    "2026-02-02": [Score(...), Score(...)],
    "2026-02-03": [Score(...)]
}
```

**Limitations:**
- Data lost on server restart
- No persistence across deployments
- Single instance only (no horizontal scaling)

### Future (Planned)

Migration to **Google Cloud Firestore** for:
- Persistent storage
- Horizontal scaling
- Real-time updates (optional)

## CORS Configuration

```python
CORS(app, resources={
    r"/api/*": {
        "origins": "*",           # Allow all origins (dev)
        "methods": ["GET", "POST", "OPTIONS"],
        "allow_headers": ["Content-Type"]
    }
})
```

**Note:** Production should restrict origins to the deployed app domain.

## Error Handling

Global error handlers return consistent JSON responses:

```python
@app.errorhandler(404)
def not_found(error):
    return jsonify({"success": False, "error": "Resource not found"}), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({"success": False, "error": "Internal server error"}), 500
```

## Configuration

### Local Development

```python
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080, debug=True)
```

### Google App Engine (`app.yaml`)

```yaml
runtime: python311
entrypoint: gunicorn -b :$PORT app:app

instance_class: F1

automatic_scaling:
  min_instances: 0
  max_instances: 2
  target_cpu_utilization: 0.65

env_variables:
  ENV: "production"
```

## Dependencies

```
Flask==3.0.0
Flask-Cors==4.0.0
gunicorn==21.2.0
```

## Running the Server

### Local Development

```bash
cd wordle-leaderboard-server
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python app.py
```

Server runs at `http://localhost:8080`

### Google App Engine Deployment

```bash
gcloud app deploy
```

## Security Considerations

### Current Status (Milestone 0)
- No authentication required
- Anonymous score submission
- CORS allows all origins
- Suitable for development/demo only

### Future Improvements
- API key authentication
- Rate limiting
- Origin restriction
- Input sanitization (additional validation)
- HTTPS enforcement
