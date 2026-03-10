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
        Toggle a like on/off (legacy — for old clients without action field).
        Returns (is_liked, new_like_count).
        Uses atomic Increment for the count to avoid drift.
        """
        db = self._db()
        col_name = _content_collection(content_type)
        parent_ref = db.collection(col_name).document(content_id)
        like_ref = parent_ref.collection("likes").document(user_id)

        @firestore.transactional
        def _toggle(transaction):
            like_snap = like_ref.get(transaction=transaction)

            if like_snap.exists:
                transaction.delete(like_ref)
                transaction.set(parent_ref, {"like_count": firestore.Increment(-1)}, merge=True)
                return False
            else:
                transaction.set(like_ref, {"user_id": user_id, "liked_at": _now_iso()})
                transaction.set(parent_ref, {"like_count": firestore.Increment(1)}, merge=True)
                return True

        transaction = db.transaction()
        is_liked = _toggle(transaction)

        parent_snap = parent_ref.get()
        like_count = max(0, (parent_snap.to_dict() or {}).get("like_count", 0)) if parent_snap.exists else 0
        return is_liked, like_count

    def set_like(self, content_type: str, content_id: str, user_id: str, action: str) -> tuple[bool, int]:
        """
        Idempotent like/unlike (Instagram-style). Returns (is_liked, new_like_count).
        action must be "like" or "unlike".
        Sending "like" when already liked is a no-op (and vice versa).
        Uses atomic Increment for the count — only reads the like sub-doc in the transaction.
        """
        db = self._db()
        col_name = _content_collection(content_type)
        parent_ref = db.collection(col_name).document(content_id)
        like_ref = parent_ref.collection("likes").document(user_id)
        want_liked = action == "like"

        @firestore.transactional
        def _set(transaction):
            like_snap = like_ref.get(transaction=transaction)
            already_liked = like_snap.exists

            if want_liked and not already_liked:
                transaction.set(like_ref, {
                    "user_id": user_id,
                    "liked_at": _now_iso(),
                })
                transaction.set(parent_ref, {"like_count": firestore.Increment(1)}, merge=True)
                return True
            elif not want_liked and already_liked:
                transaction.delete(like_ref)
                transaction.set(parent_ref, {"like_count": firestore.Increment(-1)}, merge=True)
                return False
            else:
                return already_liked

        transaction = db.transaction()
        is_liked = _set(transaction)

        # Read committed count after the transaction (not inside it)
        parent_snap = parent_ref.get()
        like_count = max(0, (parent_snap.to_dict() or {}).get("like_count", 0)) if parent_snap.exists else 0
        return is_liked, like_count

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
        Returns like status for multiple items using batched Firestore reads.
        Reads all parent docs and like sub-docs in two bulk operations instead of 2N sequential reads.
        """
        db = self._db()
        results = {}

        if not items:
            return results

        # Build all document references upfront
        parent_refs = []
        like_refs = []
        keys = []

        for item in items:
            ct = item["content_type"]
            cid = item["content_id"]
            key = f"{ct}_{cid}"
            keys.append(key)

            col_name = _content_collection(ct)
            parent_ref = db.collection(col_name).document(cid)
            like_ref = parent_ref.collection("likes").document(user_id)
            parent_refs.append(parent_ref)
            like_refs.append(like_ref)

        # Batch read all parent documents at once
        parent_snaps = db.get_all(parent_refs)
        parent_map = {}
        for snap in parent_snaps:
            parent_map[snap.reference.path] = snap

        # Batch read all like sub-documents at once
        like_snaps = db.get_all(like_refs)
        like_map = {}
        for snap in like_snaps:
            like_map[snap.reference.path] = snap

        # Assemble results
        for i, key in enumerate(keys):
            try:
                parent_path = parent_refs[i].path
                parent_snap = parent_map.get(parent_path)
                like_count = 0
                if parent_snap and parent_snap.exists:
                    like_count = (parent_snap.to_dict() or {}).get("like_count", 0)

                like_path = like_refs[i].path
                liked = like_map.get(like_path) is not None and like_map[like_path].exists

                results[key] = {"liked": liked, "like_count": like_count}
            except Exception as e:
                logger.error(f"batch_like_status error for {key}: {e}")
                results[key] = {"liked": False, "like_count": 0}

        return results


social_repository = SocialRepository()
