#
#  social.py
#  TapIn Backend
#
#  Social features API: Likes.
#  All data persisted in Firestore — nothing stored locally on client.
#
#  Public endpoints (all require JWT):
#    POST /api/social/like               — idempotent like/unlike
#    GET  /api/social/like-status        — single item like status
#    POST /api/social/like-status/batch  — batch like status
#    GET  /api/social/health             — health check
#

import logging

from flask import Blueprint, request, jsonify, g

from middleware.auth_middleware import require_auth
from repositories.social_repository import social_repository

logger = logging.getLogger(__name__)

social_bp = Blueprint("social", __name__, url_prefix="/api/social")

VALID_CONTENT_TYPES = {"article", "event"}


# --------------------------------------------------------------------------
# Likes
# --------------------------------------------------------------------------

VALID_ACTIONS = {"like", "unlike"}


@social_bp.route("/like", methods=["POST"])
@require_auth
def set_like():
    """Idempotent like/unlike (Instagram-style). Requires 'action': 'like' or 'unlike'."""
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"success": False, "error": "Request body must be JSON"}), 400

    content_type = data.get("content_type", "")
    content_id = data.get("content_id", "")
    action = data.get("action", "")  # optional — old clients don't send this

    if content_type not in VALID_CONTENT_TYPES or not content_id:
        return jsonify({"success": False, "error": "Valid content_type and content_id required"}), 400

    try:
        if action in VALID_ACTIONS:
            # New client — idempotent like/unlike
            liked, like_count = social_repository.set_like(content_type, content_id, g.user_id, action)
        else:
            # Old client (no action field) — fall back to toggle for backward compat
            liked, like_count = social_repository.toggle_like(content_type, content_id, g.user_id)
        return jsonify({"success": True, "liked": liked, "like_count": like_count}), 200
    except Exception as e:
        logger.error(f"set_like error: {e}")
        return jsonify({"success": False, "error": "Internal server error"}), 500


@social_bp.route("/like-status", methods=["GET"])
@require_auth
def like_status():
    """Returns whether the current user has liked an item and its total count."""
    content_type = request.args.get("content_type", "")
    content_id = request.args.get("content_id", "")

    if content_type not in VALID_CONTENT_TYPES or not content_id:
        return jsonify({"success": False, "error": "Valid content_type and content_id required"}), 400

    try:
        liked, like_count = social_repository.get_like_status(content_type, content_id, g.user_id)
        return jsonify({"success": True, "liked": liked, "like_count": like_count}), 200
    except Exception as e:
        logger.error(f"like_status error: {e}")
        return jsonify({"success": False, "error": "Internal server error"}), 500


@social_bp.route("/like-status/batch", methods=["POST"])
@require_auth
def batch_like_status():
    """Returns like status for multiple items in one call."""
    data = request.get_json(silent=True)
    if not data or "items" not in data:
        return jsonify({"success": False, "error": "items array required"}), 400

    try:
        results = social_repository.batch_like_status(data["items"], g.user_id)
        return jsonify({"success": True, "results": results}), 200
    except Exception as e:
        logger.error(f"batch_like_status error: {e}")
        return jsonify({"success": False, "error": "Internal server error"}), 500


# --------------------------------------------------------------------------
# Reconciliation (cron-only)
# --------------------------------------------------------------------------

@social_bp.route("/reconcile-likes", methods=["GET", "POST"])
def reconcile_likes():
    """Cron-only: recount like_count for all articles and events."""
    from services.social_reconciler import reconcile_like_counts
    reconcile_like_counts()
    return jsonify({"status": "ok"}), 200


# --------------------------------------------------------------------------
# Health
# --------------------------------------------------------------------------

@social_bp.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok", "service": "social"})
