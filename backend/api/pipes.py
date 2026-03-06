#
#  pipes.py
#  TapInApp - Backend Server
#
#  MARK: - Pipes Game API Blueprint
#  Endpoints for the Pipes (Flow Free style) puzzle game.
#  Provides daily AI-generated puzzles with caching.
#

import logging
from datetime import date, datetime
from flask import Blueprint, jsonify, request

from services.pipes_puzzle_generator import pipes_puzzle_generator
from services.pipes_leaderboard_service import pipes_leaderboard_service
from services.firestore_client import get_firestore_client, is_firestore_connected

logger = logging.getLogger(__name__)

pipes_bp = Blueprint("pipes", __name__, url_prefix="/api/pipes")


# ------------------------------------------------------------------------------
# MARK: - Daily Puzzle Endpoint
# ------------------------------------------------------------------------------

@pipes_bp.route("/daily", methods=["GET"])
def get_daily_puzzle():
    """
    Get today's Pipes puzzle.

    First checks Firestore cache for today's puzzle.
    If not cached, generates a new puzzle using Claude API.
    Falls back to deterministic puzzles if generation fails.

    Response:
        {
            "size": 5,
            "pairs": [
                {"color": "red", "start": {"row": 0, "col": 0}, "end": {"row": 2, "col": 3}},
                ...
            ],
            "date": "2026-03-02",
            "difficulty": "medium"
        }

    Note: Solution is intentionally omitted to prevent cheating.
    """
    today = date.today().isoformat()
    difficulty = _get_daily_difficulty()

    # Try to get cached puzzle from Firestore
    try:
        if is_firestore_connected():
            db = get_firestore_client()
            cached_doc = db.collection("pipes_puzzles").document(today).get()

            if cached_doc.exists:
                cached_data = cached_doc.to_dict()
                logger.info(f"Returning cached puzzle for {today}")

                # Return without solution
                return jsonify({
                    "size": cached_data.get("size", 5),
                    "pairs": cached_data.get("pairs", []),
                    "date": today,
                    "difficulty": cached_data.get("difficulty", difficulty),
                })
    except Exception as e:
        logger.warning(f"Firestore cache check failed: {e}")

    # Generate new puzzle
    try:
        puzzle = pipes_puzzle_generator.generate_puzzle(
            difficulty=difficulty,
            grid_size=5
        )

        # Cache in Firestore
        try:
            if is_firestore_connected():
                db = get_firestore_client()
                cache_data = {
                    "size": puzzle["size"],
                    "pairs": puzzle["pairs"],
                    "solution": puzzle.get("solution", []),
                    "difficulty": difficulty,
                    "date": today,
                    "generated_at": datetime.utcnow().isoformat(),
                }
                db.collection("pipes_puzzles").document(today).set(cache_data)
                logger.info(f"Cached new puzzle for {today}")
        except Exception as e:
            logger.warning(f"Failed to cache puzzle: {e}")

        # Return without solution
        return jsonify({
            "size": puzzle["size"],
            "pairs": puzzle["pairs"],
            "date": today,
            "difficulty": difficulty,
        })

    except Exception as e:
        logger.error(f"Puzzle generation failed: {e}")

        # Return fallback puzzle
        fallback = _get_fallback_puzzle(today)
        return jsonify({
            "size": fallback["size"],
            "pairs": fallback["pairs"],
            "date": today,
            "difficulty": difficulty,
            "fallback": True,
        })


# ------------------------------------------------------------------------------
# MARK: - Daily Five Endpoint
# ------------------------------------------------------------------------------

@pipes_bp.route("/daily-five", methods=["GET"])
def get_daily_five():
    """
    Get today's 5-puzzle set with escalating difficulty.

    Query params:
        date (optional): YYYY-MM-DD for archive mode. Defaults to today.

    Response:
        {
            "date": "2026-03-03",
            "puzzles": [
                {"index": 0, "size": 5, "pairs": [...], "difficulty": "easy"},
                {"index": 1, "size": 5, "pairs": [...], "difficulty": "easy"},
                {"index": 2, "size": 5, "pairs": [...], "difficulty": "medium"},
                {"index": 3, "size": 5, "pairs": [...], "difficulty": "medium"},
                {"index": 4, "size": 5, "pairs": [...], "difficulty": "hard"},
            ]
        }
    """
    requested_date = request.args.get("date", date.today().isoformat())

    # Validate date format
    try:
        datetime.strptime(requested_date, "%Y-%m-%d")
    except ValueError:
        return jsonify({"error": "Invalid date format. Use YYYY-MM-DD."}), 400

    difficulties = ["easy", "easy", "medium", "medium", "hard"]
    refresh = request.args.get("refresh", "").lower() == "true"

    # Try to get cached puzzle set from Firestore (skip if refresh requested)
    try:
        if not refresh and is_firestore_connected():
            db = get_firestore_client()
            cached_doc = db.collection("pipes_daily_five").document(requested_date).get()

            if cached_doc.exists:
                cached_data = cached_doc.to_dict()
                logger.info(f"Returning cached daily-five for {requested_date}")

                # Return without solutions
                puzzles = []
                for p in cached_data.get("puzzles", []):
                    puzzles.append({
                        "index": p.get("index", 0),
                        "size": p.get("size", 5),
                        "pairs": p.get("pairs", []),
                        "difficulty": p.get("difficulty", "medium"),
                    })

                return jsonify({
                    "date": requested_date,
                    "puzzles": puzzles,
                })
    except Exception as e:
        logger.warning(f"Firestore cache check failed for daily-five: {e}")

    # Generate new 5-puzzle set
    try:
        puzzles = pipes_puzzle_generator.generate_puzzle_set(
            difficulties=difficulties,
            grid_size=5
        )

        # Cache in Firestore
        try:
            if is_firestore_connected():
                db = get_firestore_client()
                cache_data = {
                    "puzzles": puzzles,
                    "date": requested_date,
                    "generated_at": datetime.utcnow().isoformat(),
                }
                db.collection("pipes_daily_five").document(requested_date).set(cache_data)
                logger.info(f"Cached daily-five for {requested_date}")
        except Exception as e:
            logger.warning(f"Failed to cache daily-five: {e}")

        return jsonify({
            "date": requested_date,
            "puzzles": puzzles,
        })

    except Exception as e:
        logger.error(f"Daily-five generation failed: {e}")

        # Return fallback puzzles (guaranteed distinct)
        fallback_puzzles = pipes_puzzle_generator._generate_deterministic_set(difficulties, 5)

        return jsonify({
            "date": requested_date,
            "puzzles": fallback_puzzles,
            "fallback": True,
        })


# ------------------------------------------------------------------------------
# MARK: - Leaderboard: Submit Score
# ------------------------------------------------------------------------------

@pipes_bp.route("/leaderboard/score", methods=["POST"])
def submit_pipes_score():
    """
    Submit a Pipes daily-five score to the leaderboard.

    Request Body (JSON):
        {
            "puzzles_completed": int,    # 1-5, required
            "total_moves": int,          # Total moves across all puzzles, required
            "total_time_seconds": int,   # Total solve time in seconds, required
            "puzzle_date": str,          # YYYY-MM-DD, required
            "username": str              # Optional, uses account name if provided
        }

    Response (201):
        { "success": true, "score": { ... } }
    """
    try:
        data = request.get_json()

        if not data:
            return jsonify({"success": False, "error": "Request body must be JSON"}), 400

        required_fields = ["puzzles_completed", "total_moves", "total_time_seconds", "puzzle_date"]
        missing = [f for f in required_fields if f not in data]
        if missing:
            return jsonify({"success": False, "error": f"Missing required fields: {', '.join(missing)}"}), 400

        puzzles_completed = data["puzzles_completed"]
        total_moves = data["total_moves"]
        total_time_seconds = data["total_time_seconds"]
        puzzle_date = data["puzzle_date"]
        username = data.get("username")

        if not isinstance(puzzles_completed, int) or not 1 <= puzzles_completed <= 5:
            return jsonify({"success": False, "error": "puzzles_completed must be an integer between 1 and 5"}), 400

        if not isinstance(total_moves, int) or total_moves < 0:
            return jsonify({"success": False, "error": "total_moves must be a non-negative integer"}), 400

        if not isinstance(total_time_seconds, int) or total_time_seconds < 0:
            return jsonify({"success": False, "error": "total_time_seconds must be a non-negative integer"}), 400

        if not isinstance(puzzle_date, str) or len(puzzle_date) != 10:
            return jsonify({"success": False, "error": "puzzle_date must be in YYYY-MM-DD format"}), 400

        score = pipes_leaderboard_service.submit_score(
            puzzles_completed=puzzles_completed,
            total_moves=total_moves,
            total_time_seconds=total_time_seconds,
            puzzle_date=puzzle_date,
            username=username
        )

        return jsonify({"success": True, "score": score.to_dict()}), 201

    except ValueError as e:
        return jsonify({"success": False, "error": str(e)}), 400
    except Exception as e:
        return jsonify({"success": False, "error": f"Internal server error: {str(e)}"}), 500


# ------------------------------------------------------------------------------
# MARK: - Leaderboard: Get Rankings
# ------------------------------------------------------------------------------

@pipes_bp.route("/leaderboard/<puzzle_date>", methods=["GET"])
def get_pipes_leaderboard(puzzle_date: str):
    """
    Get the Pipes leaderboard for a specific date.

    URL Parameters:
        puzzle_date: YYYY-MM-DD

    Query Parameters:
        limit: Optional, max entries (default: 5, max: 10)

    Response (200):
        {
            "success": true,
            "puzzle_date": "2026-03-05",
            "leaderboard": [
                {
                    "rank": 1,
                    "username": "SwiftFalcon",
                    "puzzles_completed": 5,
                    "total_moves": 42,
                    "total_time_seconds": 180
                }
            ]
        }
    """
    try:
        if len(puzzle_date) != 10 or puzzle_date[4] != "-" or puzzle_date[7] != "-":
            return jsonify({"success": False, "error": "Invalid date format. Use YYYY-MM-DD"}), 400

        limit = request.args.get("limit", default=5, type=int)
        limit = min(max(1, limit), 10)

        entries = pipes_leaderboard_service.get_leaderboard(puzzle_date, limit=limit)
        leaderboard_data = [entry.to_dict() for entry in entries]

        return jsonify({
            "success": True,
            "puzzle_date": puzzle_date,
            "leaderboard": leaderboard_data
        }), 200

    except Exception as e:
        return jsonify({"success": False, "error": f"Internal server error: {str(e)}"}), 500


# ------------------------------------------------------------------------------
# MARK: - Health Check
# ------------------------------------------------------------------------------

@pipes_bp.route("/health", methods=["GET"])
def health():
    """Health check endpoint for the Pipes API."""
    return jsonify({
        "service": "pipes",
        "status": "healthy",
        "firestore_connected": is_firestore_connected(),
    })


# ------------------------------------------------------------------------------
# MARK: - Helper Functions
# ------------------------------------------------------------------------------

def _get_daily_difficulty() -> str:
    """
    Rotate difficulty by day of week.

    Monday/Tuesday: easy
    Wednesday/Thursday/Friday: medium
    Saturday/Sunday: hard
    """
    weekday = date.today().weekday()
    difficulties = ["easy", "easy", "medium", "medium", "medium", "hard", "hard"]
    return difficulties[weekday]


def _get_fallback_puzzle(date_str: str) -> dict:
    """
    Get a deterministic fallback puzzle based on date.
    Uses the same templates as the generator service.
    """
    return pipes_puzzle_generator._generate_deterministic_puzzle("medium", 5)
