#
#  users.py
#  TapInApp - Backend Server
#
#  MARK: - User Profile API Endpoints
#
#  Public endpoints (no auth required):
#    POST /api/users/register       — create account, return JWT
#    POST /api/users/login          — validate credentials, return JWT
#    GET  /api/users/health         — Firestore connectivity check
#
#  Protected endpoints (require Authorization: Bearer <token>):
#    GET    /api/users/me                          — fetch own profile
#    DELETE /api/users/me                          — delete account
#    PATCH  /api/users/me/games/<game_type>        — update game stats
#    GET    /api/users/me/articles/saved           — list saved articles
#    POST   /api/users/me/articles/saved           — save an article
#    DELETE /api/users/me/articles/saved/<id>      — unsave an article
#    POST   /api/users/me/articles/read            — mark article as read
#    GET    /api/users/me/articles/read            — list read article IDs
#    GET    /api/users/me/events                   — list RSVPed events
#    POST   /api/users/me/events                   — RSVP to an event
#    DELETE /api/users/me/events/<event_id>        — cancel RSVP
#

from flask import Blueprint, request, jsonify, g
from services import auth_service
from services.firestore_client import is_firestore_connected
from repositories.user_repository import user_repository, VALID_GAME_TYPES
from middleware.auth_middleware import require_auth

import logging

logger = logging.getLogger(__name__)

users_bp = Blueprint("users", __name__, url_prefix="/api/users")


# ------------------------------------------------------------------------------
# MARK: - Helpers
# ------------------------------------------------------------------------------

def _public_profile(user: dict) -> dict:
    """Returns the user dict with passwordHash stripped out."""
    return {k: v for k, v in user.items() if k != "passwordHash"}


# ------------------------------------------------------------------------------
# MARK: - POST /api/users/register
# ------------------------------------------------------------------------------

@users_bp.route("/register", methods=["POST"])
def register():
    """
    Create a new user account.

    Request JSON: { "username": str, "email": str, "password": str }
    Response 201: { "success": true, "token": str, "user": { profile } }
    Error 400: missing / invalid fields
    Error 409: username or email already taken
    """
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"success": False, "error": "Request body must be JSON"}), 400

    missing = [f for f in ("username", "email", "password") if not data.get(f)]
    if missing:
        return jsonify({"success": False,
                        "error": f"Missing required fields: {', '.join(missing)}"}), 400

    username = data["username"].strip()
    email    = data["email"].strip().lower()
    password = data["password"]

    if len(username) < 3 or len(username) > 30:
        return jsonify({"success": False,
                        "error": "username must be 3–30 characters"}), 400

    if len(password) < 6:
        return jsonify({"success": False,
                        "error": "password must be at least 6 characters"}), 400

    try:
        password_hash = auth_service.hash_password(password)
        user = user_repository.create_user(username, email, password_hash)
        token = auth_service.create_token(user["id"])
        return jsonify({"success": True, "token": token, "user": user}), 201

    except ValueError as e:
        error_code = str(e)
        return jsonify({"success": False, "error": error_code}), 409

    except Exception as e:
        logger.error(f"register error: {e}")
        return jsonify({"success": False, "error": "Internal server error"}), 500


# ------------------------------------------------------------------------------
# MARK: - POST /api/users/login
# ------------------------------------------------------------------------------

@users_bp.route("/login", methods=["POST"])
def login():
    """
    Authenticate an existing user.

    Request JSON: { "username": str, "password": str }
    Response 200: { "success": true, "token": str, "user": { profile } }
    Error 401: invalid credentials
    """
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"success": False, "error": "Request body must be JSON"}), 400

    username = data.get("username", "").strip()
    password = data.get("password", "")

    if not username or not password:
        return jsonify({"success": False, "error": "username and password are required"}), 400

    try:
        user = user_repository.get_user_by_username(username)
        if not user or not auth_service.verify_password(password, user.get("passwordHash", "")):
            return jsonify({"success": False, "error": "invalid_credentials"}), 401

        token = auth_service.create_token(user["id"])
        return jsonify({"success": True, "token": token,
                        "user": _public_profile(user)}), 200

    except Exception as e:
        logger.error(f"login error: {e}")
        return jsonify({"success": False, "error": "Internal server error"}), 500


# ------------------------------------------------------------------------------
# MARK: - GET /api/users/me
# ------------------------------------------------------------------------------

@users_bp.route("/me", methods=["GET"])
@require_auth
def get_me():
    """
    Fetch the authenticated user's full profile.
    Response 200: { "success": true, "user": { profile (no passwordHash) } }
    """
    try:
        user = user_repository.get_user_by_id(g.user_id)
        if not user:
            return jsonify({"success": False, "error": "User not found"}), 404
        return jsonify({"success": True, "user": _public_profile(user)}), 200
    except Exception as e:
        logger.error(f"get_me error: {e}")
        return jsonify({"success": False, "error": "Internal server error"}), 500


# ------------------------------------------------------------------------------
# MARK: - DELETE /api/users/me
# ------------------------------------------------------------------------------

@users_bp.route("/me", methods=["DELETE"])
@require_auth
def delete_me():
    """
    Permanently delete the authenticated user's account.
    Response 200: { "success": true }
    """
    try:
        user_repository.delete_user(g.user_id)
        return jsonify({"success": True}), 200
    except Exception as e:
        logger.error(f"delete_me error: {e}")
        return jsonify({"success": False, "error": "Internal server error"}), 500


# ------------------------------------------------------------------------------
# MARK: - PATCH /api/users/me/games/<game_type>
# ------------------------------------------------------------------------------

@users_bp.route("/me/games/<game_type>", methods=["PATCH"])
@require_auth
def update_game_stats(game_type: str):
    """
    Replace the stats block for a single game.
    game_type must be one of: wordle, echo, trivia, crossword.

    Request JSON: full stats object for the game (all fields optional)
    Response 200: { "success": true, "gameStats": { <game_type>: { ... } } }
    """
    if game_type not in VALID_GAME_TYPES:
        return jsonify({
            "success": False,
            "error": f"Invalid game_type. Must be one of: {', '.join(sorted(VALID_GAME_TYPES))}"
        }), 400

    stats = request.get_json(silent=True)
    if stats is None:
        return jsonify({"success": False, "error": "Request body must be JSON"}), 400

    try:
        user_repository.update_game_stats(g.user_id, game_type, stats)
        user = user_repository.get_user_by_id(g.user_id)
        game_stats = user.get("gameStats", {}) if user else {}
        return jsonify({
            "success": True,
            "gameStats": {game_type: game_stats.get(game_type, stats)}
        }), 200
    except Exception as e:
        logger.error(f"update_game_stats error: {e}")
        return jsonify({"success": False, "error": "Internal server error"}), 500


# ------------------------------------------------------------------------------
# MARK: - Saved Articles
# ------------------------------------------------------------------------------

@users_bp.route("/me/articles/saved", methods=["GET"])
@require_auth
def get_saved_articles():
    """
    Return the list of saved articles for the authenticated user.
    Response 200: { "success": true, "savedArticles": [...] }
    """
    try:
        user = user_repository.get_user_by_id(g.user_id)
        if not user:
            return jsonify({"success": False, "error": "User not found"}), 404
        return jsonify({
            "success": True,
            "savedArticles": user.get("savedArticles", [])
        }), 200
    except Exception as e:
        logger.error(f"get_saved_articles error: {e}")
        return jsonify({"success": False, "error": "Internal server error"}), 500


@users_bp.route("/me/articles/saved", methods=["POST"])
@require_auth
def save_article():
    """
    Save an article to the user's profile.

    Request JSON: { "articleId": str, "articleURL": str, "title": str }
    Response 201: { "success": true }
    """
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"success": False, "error": "Request body must be JSON"}), 400

    missing = [f for f in ("articleId", "articleURL", "title") if not data.get(f)]
    if missing:
        return jsonify({"success": False,
                        "error": f"Missing required fields: {', '.join(missing)}"}), 400

    try:
        user_repository.add_saved_article(g.user_id, {
            "articleId":  data["articleId"],
            "articleURL": data["articleURL"],
            "title":      data["title"],
        })
        return jsonify({"success": True}), 201
    except Exception as e:
        logger.error(f"save_article error: {e}")
        return jsonify({"success": False, "error": "Internal server error"}), 500


@users_bp.route("/me/articles/saved/<article_id>", methods=["DELETE"])
@require_auth
def unsave_article(article_id: str):
    """
    Remove an article from the user's saved list.
    Response 200: { "success": true }
    """
    try:
        user_repository.remove_saved_article(g.user_id, article_id)
        return jsonify({"success": True}), 200
    except Exception as e:
        logger.error(f"unsave_article error: {e}")
        return jsonify({"success": False, "error": "Internal server error"}), 500


# ------------------------------------------------------------------------------
# MARK: - Read Articles
# ------------------------------------------------------------------------------

@users_bp.route("/me/articles/read", methods=["GET"])
@require_auth
def get_read_articles():
    """
    Return the list of read article records for the authenticated user.
    Response 200: { "success": true, "readArticles": [{ "articleId": str, "readAt": str }, ...] }
    """
    try:
        user = user_repository.get_user_by_id(g.user_id)
        if not user:
            return jsonify({"success": False, "error": "User not found"}), 404
        return jsonify({
            "success": True,
            "readArticles": user.get("readArticles", [])
        }), 200
    except Exception as e:
        logger.error(f"get_read_articles error: {e}")
        return jsonify({"success": False, "error": "Internal server error"}), 500


@users_bp.route("/me/articles/read", methods=["POST"])
@require_auth
def mark_article_read():
    """
    Mark an article as read. No-op if already marked.

    Request JSON: { "articleId": str }
    Response 201: { "success": true }
    """
    data = request.get_json(silent=True)
    if not data or not data.get("articleId"):
        return jsonify({"success": False, "error": "articleId is required"}), 400

    try:
        user_repository.add_read_article(g.user_id, data["articleId"])
        return jsonify({"success": True}), 201
    except Exception as e:
        logger.error(f"mark_article_read error: {e}")
        return jsonify({"success": False, "error": "Internal server error"}), 500


# ------------------------------------------------------------------------------
# MARK: - Event RSVPs
# ------------------------------------------------------------------------------

@users_bp.route("/me/events", methods=["GET"])
@require_auth
def get_event_rsvps():
    """
    Return the list of events the user has RSVPed to.
    Response 200: { "success": true, "eventRSVPs": [...] }
    """
    try:
        user = user_repository.get_user_by_id(g.user_id)
        if not user:
            return jsonify({"success": False, "error": "User not found"}), 404
        return jsonify({
            "success": True,
            "eventRSVPs": user.get("eventRSVPs", [])
        }), 200
    except Exception as e:
        logger.error(f"get_event_rsvps error: {e}")
        return jsonify({"success": False, "error": "Internal server error"}), 500


@users_bp.route("/me/events", methods=["POST"])
@require_auth
def rsvp_event():
    """
    RSVP to an event. No-op if already RSVPed.

    Request JSON: { "eventId": str, "eventTitle": str }
    Response 201: { "success": true }
    """
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"success": False, "error": "Request body must be JSON"}), 400

    missing = [f for f in ("eventId", "eventTitle") if not data.get(f)]
    if missing:
        return jsonify({"success": False,
                        "error": f"Missing required fields: {', '.join(missing)}"}), 400

    try:
        user_repository.add_event_rsvp(g.user_id, {
            "eventId":    data["eventId"],
            "eventTitle": data["eventTitle"],
        })
        return jsonify({"success": True}), 201
    except Exception as e:
        logger.error(f"rsvp_event error: {e}")
        return jsonify({"success": False, "error": "Internal server error"}), 500


@users_bp.route("/me/events/<event_id>", methods=["DELETE"])
@require_auth
def cancel_rsvp(event_id: str):
    """
    Cancel an event RSVP.
    Response 200: { "success": true }
    """
    try:
        user_repository.remove_event_rsvp(g.user_id, event_id)
        return jsonify({"success": True}), 200
    except Exception as e:
        logger.error(f"cancel_rsvp error: {e}")
        return jsonify({"success": False, "error": "Internal server error"}), 500


# ------------------------------------------------------------------------------
# MARK: - GET /api/users/health
# ------------------------------------------------------------------------------

@users_bp.route("/health", methods=["GET"])
def health():
    """
    Health check — verifies Firestore is reachable.
    Response 200: { "status": "healthy"|"degraded", "firestore": "connected"|"disconnected" }
    """
    try:
        connected = is_firestore_connected()
        return jsonify({
            "status":    "healthy" if connected else "degraded",
            "service":   "user-profiles",
            "firestore": "connected" if connected else "disconnected",
        }), 200
    except Exception as e:
        return jsonify({
            "status":  "degraded",
            "service": "user-profiles",
            "error":   str(e),
        }), 200
