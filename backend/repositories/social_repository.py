#
#  social_repository.py
#  TapIn Backend
#
#  Firestore repository for likes and comments.
#  All social data lives in Firestore sub-collections — nothing local.
#
#  Likes:   {content_type}s/{content_id}/likes/{user_id}
#  Comments: {content_type}s/{content_id}/comments/{comment_id}
#

import uuid
import logging
import time
from datetime import datetime, timezone
from typing import Optional

from google.cloud import firestore
from services.firestore_client import get_firestore_client

logger = logging.getLogger(__name__)

# In-memory rate limiter for comments: user_id -> list of timestamps
_comment_timestamps: dict[str, list[float]] = {}
COMMENT_RATE_LIMIT = 5
COMMENT_RATE_WINDOW = 600  # 10 minutes


def _now_iso() -> str:
    return datetime.now(tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _content_collection(content_type: str) -> str:
    """Map content_type to Firestore collection name."""
    mapping = {"article": "articles", "event": "events", "comment": "comments"}
    return mapping.get(content_type, f"{content_type}s")


class SocialRepository:

    def _db(self):
        return get_firestore_client()

    # ------------------------------------------------------------------
    # Likes
    # ------------------------------------------------------------------

    def toggle_like(self, content_type: str, content_id: str, user_id: str) -> tuple[bool, int]:
        """
        Toggle a like on/off. Returns (is_liked, new_like_count).
        Uses a Firestore transaction to ensure atomicity.
        """
        db = self._db()
        col_name = _content_collection(content_type)
        parent_ref = db.collection(col_name).document(content_id)
        like_ref = parent_ref.collection("likes").document(user_id)

        @firestore.transactional
        def _toggle(transaction):
            like_snap = like_ref.get(transaction=transaction)
            parent_snap = parent_ref.get(transaction=transaction)
            current_count = (parent_snap.to_dict() or {}).get("like_count", 0) if parent_snap.exists else 0

            if like_snap.exists:
                # Unlike
                transaction.delete(like_ref)
                new_count = max(0, current_count - 1)
                transaction.set(parent_ref, {"like_count": new_count}, merge=True)
                return False, new_count
            else:
                # Like
                transaction.set(like_ref, {
                    "user_id": user_id,
                    "liked_at": _now_iso(),
                })
                new_count = current_count + 1
                transaction.set(parent_ref, {"like_count": new_count}, merge=True)
                return True, new_count

        transaction = db.transaction()
        return _toggle(transaction)

    def get_like_status(self, content_type: str, content_id: str, user_id: str) -> tuple[bool, int]:
        """Returns (is_liked_by_user, like_count)."""
        db = self._db()
        col_name = _content_collection(content_type)
        parent_ref = db.collection(col_name).document(content_id)

        parent_snap = parent_ref.get()
        like_count = (parent_snap.to_dict() or {}).get("like_count", 0) if parent_snap.exists else 0

        like_snap = parent_ref.collection("likes").document(user_id).get()
        return like_snap.exists, like_count

    def batch_like_status(self, items: list[dict], user_id: str) -> dict:
        """
        Returns like status for multiple items.
        Key format: "{content_type}_{content_id}"
        """
        db = self._db()
        results = {}
        for item in items:
            ct = item["content_type"]
            cid = item["content_id"]
            key = f"{ct}_{cid}"
            try:
                liked, count = self.get_like_status(ct, cid, user_id)
                results[key] = {"liked": liked, "like_count": count}
            except Exception as e:
                logger.error(f"batch_like_status error for {key}: {e}")
                results[key] = {"liked": False, "like_count": 0}
        return results

    # ------------------------------------------------------------------
    # Comments
    # ------------------------------------------------------------------

    def is_rate_limited(self, user_id: str) -> bool:
        """Check if user has exceeded comment rate limit."""
        now = time.time()
        cutoff = now - COMMENT_RATE_WINDOW
        timestamps = _comment_timestamps.get(user_id, [])
        timestamps = [t for t in timestamps if t > cutoff]
        _comment_timestamps[user_id] = timestamps
        return len(timestamps) >= COMMENT_RATE_LIMIT

    def create_comment(self, content_type: str, content_id: str,
                       user_id: str, author_name: str, body: str) -> dict:
        """
        Creates a comment in pending state. Returns the comment doc.
        """
        # Record for rate limiting
        now = time.time()
        _comment_timestamps.setdefault(user_id, []).append(now)

        db = self._db()
        col_name = _content_collection(content_type)
        comment_id = str(uuid.uuid4())
        now_iso = _now_iso()

        doc = {
            "comment_id": comment_id,
            "author_id": user_id,
            "author_name": author_name,
            "body": body,
            "status": "pending",
            "moderation_score": None,
            "moderation_reason": None,
            "like_count": 0,
            "created_at": now_iso,
            "updated_at": now_iso,
        }

        db.collection(col_name).document(content_id) \
            .collection("comments").document(comment_id).set(doc)

        logger.info(f"Comment created: {comment_id} on {content_type}/{content_id} by {user_id}")
        return doc

    def update_comment_moderation(self, content_type: str, content_id: str,
                                  comment_id: str, status: str,
                                  score: float, reason: str | None) -> None:
        """Updates a comment's moderation status after AI review."""
        db = self._db()
        col_name = _content_collection(content_type)
        db.collection(col_name).document(content_id) \
            .collection("comments").document(comment_id).update({
                "status": status,
                "moderation_score": score,
                "moderation_reason": reason,
                "updated_at": _now_iso(),
            })

    def get_approved_comments(self, content_type: str, content_id: str,
                              user_id: str, page: int = 1,
                              per_page: int = 20) -> dict:
        """
        Returns approved comments for a piece of content, paginated.
        Only status=='approved' comments are returned.
        """
        db = self._db()
        col_name = _content_collection(content_type)
        comments_ref = db.collection(col_name).document(content_id).collection("comments")

        # Count total approved
        total_query = comments_ref.where("status", "==", "approved")
        total = len(list(total_query.stream()))

        # Paginated fetch
        query = comments_ref.where("status", "==", "approved") \
            .order_by("created_at", direction=firestore.Query.DESCENDING) \
            .offset((page - 1) * per_page) \
            .limit(per_page)

        comments = []
        for snap in query.stream():
            doc = snap.to_dict()
            # Check if current user liked this comment
            like_snap = comments_ref.document(doc["comment_id"]) \
                .collection("likes").document(user_id).get() if user_id else None
            liked_by_me = like_snap.exists if like_snap else False

            comments.append({
                "comment_id": doc["comment_id"],
                "author_name": doc.get("author_name", "Anonymous"),
                "body": doc.get("body", ""),
                "like_count": doc.get("like_count", 0),
                "liked_by_me": liked_by_me,
                "created_at": doc.get("created_at", ""),
                "is_mine": doc.get("author_id") == user_id,
            })

        return {
            "comments": comments,
            "total": total,
            "page": page,
            "has_more": (page * per_page) < total,
        }

    def delete_comment(self, content_type: str, content_id: str,
                       comment_id: str, user_id: str) -> bool:
        """
        Deletes a comment if the requesting user is the author.
        Returns True if deleted, False if not authorized.
        """
        db = self._db()
        col_name = _content_collection(content_type)
        comment_ref = db.collection(col_name).document(content_id) \
            .collection("comments").document(comment_id)

        snap = comment_ref.get()
        if not snap.exists:
            return True  # Already gone

        doc = snap.to_dict()
        if doc.get("author_id") != user_id:
            return False

        comment_ref.delete()
        return True

    def get_comment_by_id(self, content_type: str, content_id: str,
                          comment_id: str) -> Optional[dict]:
        db = self._db()
        col_name = _content_collection(content_type)
        snap = db.collection(col_name).document(content_id) \
            .collection("comments").document(comment_id).get()
        return snap.to_dict() if snap.exists else None


social_repository = SocialRepository()
