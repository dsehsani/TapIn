#
#  leaderboard.py
#  TapInApp - Wordle Leaderboard Server
#
#  Created by Darius Ehsani on 2/2/26.
#
#  MARK: - Leaderboard API Endpoints
#  This file contains the Flask Blueprint with REST API endpoints for
#  the Wordle leaderboard system.
#
#  Endpoints:
#  - POST /api/leaderboard/score    - Submit a new score
#  - GET  /api/leaderboard/<date>   - Get leaderboard for a specific date
#
#  All endpoints return JSON responses with appropriate HTTP status codes.
#

from flask import Blueprint, request, jsonify
from services.leaderboard_service import leaderboard_service
from services.unified_leaderboard_service import unified_leaderboard_service
from models import VALID_GAME_TYPES


# ------------------------------------------------------------------------------
# MARK: - Blueprint Setup
# ------------------------------------------------------------------------------

# Create Blueprint with /api/leaderboard prefix
leaderboard_bp = Blueprint("leaderboard", __name__, url_prefix="/api/leaderboard")


# ------------------------------------------------------------------------------
# MARK: - Legacy POST /api/leaderboard/score (Now handled by unified endpoint below)
# ------------------------------------------------------------------------------
# The submit_score endpoint is now unified and supports both legacy Wordle format
# and the new unified format with game_type. See submit_unified_score() below.


# ------------------------------------------------------------------------------
# MARK: - GET /api/leaderboard/<date>
# ------------------------------------------------------------------------------

@leaderboard_bp.route("/<puzzle_date>", methods=["GET"])
def get_leaderboard(puzzle_date: str):
    """
    Get the leaderboard for a specific puzzle date.

    URL Parameters:
        puzzle_date: The date in YYYY-MM-DD format

    Query Parameters:
        limit: Optional, max number of entries (default: 5, max: 10)

    Response (200 OK):
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
                }
            ]
        }

    Response when no scores exist (200 OK):
        {
            "success": true,
            "puzzle_date": "2026-02-02",
            "leaderboard": []
        }

    Example curl:
        curl http://localhost:8080/api/leaderboard/2026-02-02
        curl http://localhost:8080/api/leaderboard/2026-02-02?limit=3
    """
    try:
        # Validate puzzle_date format (basic check)
        if len(puzzle_date) != 10 or puzzle_date[4] != "-" or puzzle_date[7] != "-":
            return jsonify({
                "success": False,
                "error": "Invalid date format. Use YYYY-MM-DD"
            }), 400

        # Get optional limit parameter (default: 5, max: 10)
        limit = request.args.get("limit", default=5, type=int)
        limit = min(max(1, limit), 10)  # Clamp between 1 and 10

        # Get leaderboard from service
        entries = leaderboard_service.get_leaderboard(puzzle_date, limit=limit)

        # Convert entries to dictionaries for JSON response
        leaderboard_data = [entry.to_dict() for entry in entries]

        return jsonify({
            "success": True,
            "puzzle_date": puzzle_date,
            "leaderboard": leaderboard_data
        }), 200

    except Exception as e:
        # Handle unexpected errors
        return jsonify({
            "success": False,
            "error": f"Internal server error: {str(e)}"
        }), 500


# ------------------------------------------------------------------------------
# MARK: - Health Check Endpoint
# ------------------------------------------------------------------------------

@leaderboard_bp.route("/health", methods=["GET"])
def health_check():
    """
    Health check endpoint for monitoring.

    Response (200 OK):
        {
            "status": "healthy",
            "service": "wordle-leaderboard"
        }

    Example curl:
        curl http://localhost:8080/api/leaderboard/health
    """
    return jsonify({
        "status": "healthy",
        "service": "unified-leaderboard",
        "supported_games": VALID_GAME_TYPES
    }), 200


# ------------------------------------------------------------------------------
# MARK: - Unified Leaderboard Endpoints
# ------------------------------------------------------------------------------

@leaderboard_bp.route("/<game_type>/<date>", methods=["GET"])
def get_unified_leaderboard(game_type: str, date: str):
    """
    Get the leaderboard for a specific game type and date.

    URL Parameters:
        game_type: Type of game (wordle, echo, crossword, trivia)
        date: The date in YYYY-MM-DD format

    Query Parameters:
        limit: Optional, max number of entries (default: 5, max: 10)

    Response (200 OK):
        {
            "success": true,
            "game_type": "echo",
            "date": "2026-02-20",
            "leaderboard": [
                {
                    "id": "uuid",
                    "rank": 1,
                    "username": "SwiftFalcon",
                    "score": 1250,
                    "game_type": "echo",
                    "date": "2026-02-20",
                    "metadata": {...}
                }
            ]
        }

    Example curl:
        curl http://localhost:8080/api/leaderboard/echo/2026-02-20
        curl http://localhost:8080/api/leaderboard/wordle/2026-02-20?limit=3
    """
    try:
        # Validate game_type
        if game_type not in VALID_GAME_TYPES:
            return jsonify({
                "success": False,
                "error": f"Invalid game_type. Must be one of: {', '.join(VALID_GAME_TYPES)}"
            }), 400

        # Validate date format
        if len(date) != 10 or date[4] != "-" or date[7] != "-":
            return jsonify({
                "success": False,
                "error": "Invalid date format. Use YYYY-MM-DD"
            }), 400

        # Get optional limit parameter
        limit = request.args.get("limit", default=5, type=int)
        limit = min(max(1, limit), 10)

        # Get leaderboard from unified service
        entries = unified_leaderboard_service.get_leaderboard(game_type, date, limit=limit)
        leaderboard_data = [entry.to_dict() for entry in entries]

        return jsonify({
            "success": True,
            "game_type": game_type,
            "date": date,
            "leaderboard": leaderboard_data
        }), 200

    except Exception as e:
        return jsonify({
            "success": False,
            "error": f"Internal server error: {str(e)}"
        }), 500


@leaderboard_bp.route("/sync", methods=["POST"])
def sync_scores():
    """
    Batch sync multiple scores at once.

    Request Body (JSON):
        {
            "scores": [
                {
                    "game_type": "echo",
                    "score": 1200,
                    "date": "2026-02-20",
                    "username": "SwiftFalcon",
                    "metadata": {...}
                },
                ...
            ]
        }

    Response (200 OK):
        {
            "success": true,
            "synced_count": 3,
            "results": [
                {
                    "local_id": null,
                    "remote_id": "uuid",
                    "success": true,
                    "error": null
                },
                ...
            ]
        }

    Example curl:
        curl -X POST http://localhost:8080/api/leaderboard/sync \
             -H "Content-Type: application/json" \
             -d '{"scores": [{"game_type": "echo", "score": 1200, "date": "2026-02-20"}]}'
    """
    try:
        data = request.get_json()

        if not data:
            return jsonify({
                "success": False,
                "error": "Request body must be JSON"
            }), 400

        scores = data.get("scores", [])
        if not isinstance(scores, list):
            return jsonify({
                "success": False,
                "error": "scores must be an array"
            }), 400

        results = unified_leaderboard_service.sync_scores(scores)
        synced_count = sum(1 for r in results if r.get("success"))

        return jsonify({
            "success": True,
            "synced_count": synced_count,
            "results": results
        }), 200

    except Exception as e:
        return jsonify({
            "success": False,
            "error": f"Internal server error: {str(e)}"
        }), 500


# Override score submission to support game_type parameter
@leaderboard_bp.route("/score", methods=["POST"])
def submit_unified_score():
    """
    Submit a new score to the leaderboard.

    Supports both legacy Wordle format and unified format:

    Unified Format (JSON):
        {
            "game_type": "echo",      # Required for non-Wordle
            "score": 1200,            # Required
            "date": "2026-02-20",     # Required
            "username": "SwiftFalcon",# Optional (auto-generated)
            "metadata": {...}         # Optional, game-specific data
        }

    Legacy Wordle Format (JSON):
        {
            "guesses": 4,             # Required for Wordle
            "time_seconds": 120,      # Required for Wordle
            "puzzle_date": "2026-02-20"
        }

    Response (201 Created):
        {
            "success": true,
            "id": "uuid",
            "rank": 1,
            "username": "SwiftFalcon"
        }

    Example curl:
        curl -X POST http://localhost:8080/api/leaderboard/score \
             -H "Content-Type: application/json" \
             -d '{"game_type": "echo", "score": 1200, "date": "2026-02-20"}'
    """
    try:
        data = request.get_json()

        if not data:
            return jsonify({
                "success": False,
                "error": "Request body must be JSON"
            }), 400

        # Check if this is unified format (has game_type) or legacy Wordle format
        if "game_type" in data:
            # Unified format
            game_type = data.get("game_type")
            if game_type not in VALID_GAME_TYPES:
                return jsonify({
                    "success": False,
                    "error": f"Invalid game_type. Must be one of: {', '.join(VALID_GAME_TYPES)}"
                }), 400

            score_value = data.get("score", 0)
            date = data.get("date")
            username = data.get("username")
            metadata = data.get("metadata", {})

            if not date:
                return jsonify({
                    "success": False,
                    "error": "date is required"
                }), 400

            game_score = unified_leaderboard_service.submit_score(
                game_type=game_type,
                score=score_value,
                date=date,
                username=username,
                metadata=metadata
            )

            # Calculate rank
            entries = unified_leaderboard_service.get_leaderboard(game_type, date, limit=100)
            rank = next((e.rank for e in entries if e.id == game_score.id), None)

            return jsonify({
                "success": True,
                "id": game_score.id,
                "rank": rank,
                "username": game_score.username
            }), 201

        else:
            # Legacy Wordle format - redirect to original handler
            required_fields = ["guesses", "time_seconds", "puzzle_date"]
            missing_fields = [field for field in required_fields if field not in data]

            if missing_fields:
                return jsonify({
                    "success": False,
                    "error": f"Missing required fields: {', '.join(missing_fields)}"
                }), 400

            guesses = data["guesses"]
            time_seconds = data["time_seconds"]
            puzzle_date = data["puzzle_date"]

            if not isinstance(guesses, int) or not 1 <= guesses <= 6:
                return jsonify({
                    "success": False,
                    "error": "guesses must be an integer between 1 and 6"
                }), 400

            if not isinstance(time_seconds, int) or time_seconds < 0:
                return jsonify({
                    "success": False,
                    "error": "time_seconds must be a non-negative integer"
                }), 400

            if not isinstance(puzzle_date, str) or len(puzzle_date) != 10:
                return jsonify({
                    "success": False,
                    "error": "puzzle_date must be in YYYY-MM-DD format"
                }), 400

            score = leaderboard_service.submit_score(
                guesses=guesses,
                time_seconds=time_seconds,
                puzzle_date=puzzle_date
            )

            return jsonify({
                "success": True,
                "score": score.to_dict()
            }), 201

    except ValueError as e:
        return jsonify({
            "success": False,
            "error": str(e)
        }), 400

    except Exception as e:
        return jsonify({
            "success": False,
            "error": f"Internal server error: {str(e)}"
        }), 500
