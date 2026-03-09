#
#  social_repository.py
#  TapIn Backend
#
#  Firestore repository for likes.
#  All social data lives in Firestore sub-collections — nothing local.
#
#  Likes: {content_type}s/{content_id}/likes/{user_id}
#

import logging
from datetime import datetime, timezone

from google.cloud import firestore
from services.firestore_client import get_firestore_client

logger = logging.getLogger(__name__)


def _now_iso() -> str:
    return datetime.now(tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _content_collection(content_type: str) -> str:
    """Map content_type to Firestore collection name."""
    mapping = {"article": "articles", "event": "events"}
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


social_repository = SocialRepository()
