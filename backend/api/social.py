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
# Diagnostics
# --------------------------------------------------------------------------

@social_bp.route("/debug/likes", methods=["GET"])
def debug_likes():
    """
    Diagnostic endpoint — shows raw Firestore state for a content item.
    Use to verify likes are persisted and visible across users.

    Query params:
        content_type (str): "article" or "event"
        content_id   (str): the socialId
    """
    content_type = request.args.get("content_type", "")
    content_id = request.args.get("content_id", "")

    if content_type not in VALID_CONTENT_TYPES or not content_id:
        return jsonify({"success": False, "error": "content_type and content_id required"}), 400

    try:
        from services.firestore_client import get_firestore_client
        db = get_firestore_client()

        col_name = "articles" if content_type == "article" else "events"
        parent_ref = db.collection(col_name).document(content_id)
        parent_snap = parent_ref.get()

        # Read all like sub-documents
        likes_docs = list(parent_ref.collection("likes").stream())
        likers = []
        for doc in likes_docs:
            data = doc.to_dict() or {}
            likers.append({
                "user_id": doc.id,
                "liked_at": data.get("liked_at", "unknown"),
            })

        parent_data = parent_snap.to_dict() if parent_snap.exists else None
        stored_count = (parent_data or {}).get("like_count", 0) if parent_data else 0

        return jsonify({
            "success": True,
            "firestore_project": db.project,
            "document_path": parent_ref.path,
            "document_exists": parent_snap.exists,
            "stored_like_count": stored_count,
            "actual_like_sub_docs": len(likers),
            "count_matches": stored_count == len(likers),
            "likers": likers,
            "parent_data_keys": list((parent_data or {}).keys()),
        }), 200

    except Exception as e:
        logger.error(f"debug_likes error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@social_bp.route("/debug/test-like", methods=["POST"])
def debug_test_like():
    """
    End-to-end like test — creates a like, reads it back, then cleans up.
    No auth required. Uses a fake test user ID.

    Body: { "content_type": "article", "content_id": "test_debug_item" }
    """
    data = request.get_json(silent=True) or {}
    content_type = data.get("content_type", "article")
    content_id = data.get("content_id", "test_debug_item")
    test_user = "debug-test-user-000"

    if content_type not in VALID_CONTENT_TYPES:
        return jsonify({"success": False, "error": "Invalid content_type"}), 400

    steps = {}
    try:
        # Step 1: Like
        liked, count = social_repository.set_like(content_type, content_id, test_user, "like")
        steps["1_like"] = {"liked": liked, "like_count": count}

        # Step 2: Read back
        read_liked, read_count = social_repository.get_like_status(content_type, content_id, test_user)
        steps["2_read_back"] = {"liked": read_liked, "like_count": read_count}

        # Step 3: Unlike (cleanup)
        unliked, final_count = social_repository.set_like(content_type, content_id, test_user, "unlike")
        steps["3_unlike_cleanup"] = {"liked": unliked, "like_count": final_count}

        all_passed = (
            steps["1_like"]["liked"] is True
            and steps["2_read_back"]["liked"] is True
            and steps["3_unlike_cleanup"]["liked"] is False
        )

        return jsonify({
            "success": True,
            "all_passed": all_passed,
            "steps": steps,
        }), 200

    except Exception as e:
        logger.error(f"debug_test_like error: {e}")
        return jsonify({"success": False, "error": str(e), "steps": steps}), 500


# --------------------------------------------------------------------------
# Health
# --------------------------------------------------------------------------

@social_bp.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok", "service": "social"})
