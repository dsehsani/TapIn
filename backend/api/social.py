#
#  social.py
#  TapIn Backend
#
#  Social features API: Likes and Comments.
#  All data persisted in Firestore — nothing stored locally on client.
#
#  Public endpoints (all require JWT):
#    POST /api/social/like               — toggle like
#    GET  /api/social/like-status        — single item like status
#    POST /api/social/like-status/batch  — batch like status
#    POST /api/social/comment            — submit comment (enters pending)
#    GET  /api/social/comments           — fetch approved comments
#    DELETE /api/social/comment/<id>     — delete own comment
#    GET  /api/social/health             — health check
#

import logging
import threading

from flask import Blueprint, request, jsonify, g

from middleware.auth_middleware import require_auth
from repositories.social_repository import social_repository
from repositories.user_repository import user_repository
from services.moderation import moderation_service

logger = logging.getLogger(__name__)

social_bp = Blueprint("social", __name__, url_prefix="/api/social")

VALID_CONTENT_TYPES = {"article", "event", "comment"}
VALID_COMMENT_CONTENT_TYPES = {"article", "event"}


# --------------------------------------------------------------------------
# Likes
# --------------------------------------------------------------------------

@social_bp.route("/like", methods=["POST"])
@require_auth
def toggle_like():
    """Toggle a like on/off for a piece of content."""
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"success": False, "error": "Request body must be JSON"}), 400

    content_type = data.get("content_type", "")
    content_id = data.get("content_id", "")

    if content_type not in VALID_CONTENT_TYPES or not content_id:
        return jsonify({"success": False, "error": "Valid content_type and content_id required"}), 400

    try:
        liked, like_count = social_repository.toggle_like(content_type, content_id, g.user_id)
        return jsonify({"success": True, "liked": liked, "like_count": like_count}), 200
    except Exception as e:
        logger.error(f"toggle_like error: {e}")
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
# Comments
# --------------------------------------------------------------------------

@social_bp.route("/comment", methods=["POST"])
@require_auth
def post_comment():
    """
    Submit a new comment. Enters 'pending' state for AI moderation.
    Not shown to any user until approved.
    """
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"success": False, "error": "Request body must be JSON"}), 400

    content_type = data.get("content_type", "")
    content_id = data.get("content_id", "")
    body = data.get("body", "").strip()

    if content_type not in VALID_COMMENT_CONTENT_TYPES or not content_id:
        return jsonify({"success": False, "error": "Valid content_type and content_id required"}), 400
    if not body:
        return jsonify({"success": False, "error": "Comment body is required"}), 400
    if len(body) > 500:
        return jsonify({"success": False, "error": "Comment must be 500 characters or less"}), 400

    # Rate limiting
    if social_repository.is_rate_limited(g.user_id):
        return jsonify({"success": False, "error": "Too many comments. Please wait a few minutes."}), 429

    try:
        # Get author name from user profile
        user = user_repository.get_user_by_id(g.user_id)
        author_name = (user or {}).get("username", "Anonymous")

        # Create comment in pending state
        comment = social_repository.create_comment(
            content_type=content_type,
            content_id=content_id,
            user_id=g.user_id,
            author_name=author_name,
            body=body,
        )

        # Run AI moderation in background thread — don't block the response
        comment_id = comment["comment_id"]
        threading.Thread(
            target=_moderate_comment_async,
            args=(content_type, content_id, comment_id, body),
            daemon=True,
        ).start()

        return jsonify({
            "success": True,
            "status": "pending",
            "message": "Your comment is being reviewed.",
        }), 201

    except Exception as e:
        logger.error(f"post_comment error: {e}")
        return jsonify({"success": False, "error": "Internal server error"}), 500


def _moderate_comment_async(content_type: str, content_id: str,
                            comment_id: str, body: str) -> None:
    """Background thread: run AI moderation and update the comment status."""
    try:
        result = moderation_service.moderate_comment(body)
        status = "approved" if result.approved else "rejected"
        social_repository.update_comment_moderation(
            content_type=content_type,
            content_id=content_id,
            comment_id=comment_id,
            status=status,
            score=result.score,
            reason=result.reason,
        )
        logger.info(f"Comment {comment_id} moderated: {status} (score={result.score})")
    except Exception as e:
        # Fail-open: approve if moderation crashes
        logger.error(f"Moderation thread error for {comment_id}: {e}")
        try:
            social_repository.update_comment_moderation(
                content_type=content_type,
                content_id=content_id,
                comment_id=comment_id,
                status="approved",
                score=0.0,
                reason="moderation_unavailable",
            )
        except Exception:
            pass


@social_bp.route("/comments", methods=["GET"])
@require_auth
def get_comments():
    """Fetch approved comments for a piece of content, paginated."""
    content_type = request.args.get("content_type", "")
    content_id = request.args.get("content_id", "")
    page = request.args.get("page", 1, type=int)
    per_page = request.args.get("per_page", 20, type=int)

    if content_type not in VALID_COMMENT_CONTENT_TYPES or not content_id:
        return jsonify({"success": False, "error": "Valid content_type and content_id required"}), 400

    per_page = min(per_page, 50)  # Cap at 50

    try:
        result = social_repository.get_approved_comments(
            content_type=content_type,
            content_id=content_id,
            user_id=g.user_id,
            page=page,
            per_page=per_page,
        )
        return jsonify({"success": True, **result}), 200
    except Exception as e:
        logger.error(f"get_comments error: {e}")
        return jsonify({"success": False, "error": "Internal server error"}), 500


@social_bp.route("/comment/<comment_id>", methods=["DELETE"])
@require_auth
def delete_comment(comment_id: str):
    """Delete own comment."""
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"success": False, "error": "Request body must be JSON"}), 400

    content_type = data.get("content_type", "")
    content_id = data.get("content_id", "")

    if content_type not in VALID_COMMENT_CONTENT_TYPES or not content_id:
        return jsonify({"success": False, "error": "Valid content_type and content_id required"}), 400

    try:
        deleted = social_repository.delete_comment(
            content_type=content_type,
            content_id=content_id,
            comment_id=comment_id,
            user_id=g.user_id,
        )
        if not deleted:
            return jsonify({"success": False, "error": "Not authorized to delete this comment"}), 403
        return jsonify({"success": True}), 200
    except Exception as e:
        logger.error(f"delete_comment error: {e}")
        return jsonify({"success": False, "error": "Internal server error"}), 500


# --------------------------------------------------------------------------
# Health
# --------------------------------------------------------------------------

@social_bp.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok", "service": "social"})
