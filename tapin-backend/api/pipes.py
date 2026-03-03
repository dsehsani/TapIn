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
