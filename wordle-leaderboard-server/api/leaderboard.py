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


# ------------------------------------------------------------------------------
# MARK: - Blueprint Setup
# ------------------------------------------------------------------------------

# Create Blueprint with /api/leaderboard prefix
leaderboard_bp = Blueprint("leaderboard", __name__, url_prefix="/api/leaderboard")


# ------------------------------------------------------------------------------
# MARK: - POST /api/leaderboard/score
# ------------------------------------------------------------------------------

@leaderboard_bp.route("/score", methods=["POST"])
def submit_score():
    """
    Submit a new score to the leaderboard.

    Request Body (JSON):
        {
            "guesses": int,        # Number of guesses (1-6), required
            "time_seconds": int,   # Time taken in seconds, required
            "puzzle_date": str     # Date in YYYY-MM-DD format, required
        }

    Response (201 Created):
        {
            "success": true,
            "score": {
                "id": "uuid-string",
                "username": "SwiftFalcon",
                "guesses": 4,
                "time_seconds": 120,
                "puzzle_date": "2026-02-02"
            }
        }

    Error Response (400 Bad Request):
        {
            "success": false,
            "error": "Error message describing what went wrong"
        }

    Example curl:
        curl -X POST http://localhost:8080/api/leaderboard/score \
             -H "Content-Type: application/json" \
             -d '{"guesses": 4, "time_seconds": 120, "puzzle_date": "2026-02-02"}'
    """
    try:
        # Parse JSON request body
        data = request.get_json()

        # Validate required fields are present
        if not data:
            return jsonify({
                "success": False,
                "error": "Request body must be JSON"
            }), 400

        required_fields = ["guesses", "time_seconds", "puzzle_date"]
        missing_fields = [field for field in required_fields if field not in data]

        if missing_fields:
            return jsonify({
                "success": False,
                "error": f"Missing required fields: {', '.join(missing_fields)}"
            }), 400

        # Extract and validate field values
        guesses = data["guesses"]
        time_seconds = data["time_seconds"]
        puzzle_date = data["puzzle_date"]

        # Validate guesses is an integer between 1 and 6
        if not isinstance(guesses, int) or not 1 <= guesses <= 6:
            return jsonify({
                "success": False,
                "error": "guesses must be an integer between 1 and 6"
            }), 400

        # Validate time_seconds is a positive integer
        if not isinstance(time_seconds, int) or time_seconds < 0:
            return jsonify({
                "success": False,
                "error": "time_seconds must be a non-negative integer"
            }), 400

        # Validate puzzle_date format (basic check for YYYY-MM-DD)
        if not isinstance(puzzle_date, str) or len(puzzle_date) != 10:
            return jsonify({
                "success": False,
                "error": "puzzle_date must be in YYYY-MM-DD format"
            }), 400

        # Submit the score using the service
        score = leaderboard_service.submit_score(
            guesses=guesses,
            time_seconds=time_seconds,
            puzzle_date=puzzle_date
        )

        # Return success response with created score
        return jsonify({
            "success": True,
            "score": score.to_dict()
        }), 201

    except ValueError as e:
        # Handle validation errors from the service
        return jsonify({
            "success": False,
            "error": str(e)
        }), 400

    except Exception as e:
        # Handle unexpected errors
        return jsonify({
            "success": False,
            "error": f"Internal server error: {str(e)}"
        }), 500


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
        "service": "wordle-leaderboard"
    }), 200
