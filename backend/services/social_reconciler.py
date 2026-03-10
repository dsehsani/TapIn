#
#  social_reconciler.py
#  TapIn Backend
#
#  Daily cron job that recounts likes sub-collections and fixes any drifted like_count values.
#

import logging

from services.firestore_client import get_firestore_client

logger = logging.getLogger(__name__)


def reconcile_like_counts():
    """
    Recount likes sub-collections and fix any drifted like_count values.
    Run as a cron job — not time-critical.
    """
    db = get_firestore_client()

    for collection_name in ["articles", "events"]:
        docs = db.collection(collection_name).stream()
        for doc in docs:
            likes_count = sum(1 for _ in doc.reference.collection("likes").stream())
            stored_count = (doc.to_dict() or {}).get("like_count", 0)
            if likes_count != stored_count:
                logger.warning(
                    f"Drift detected: {collection_name}/{doc.id} "
                    f"stored={stored_count} actual={likes_count}"
                )
                doc.reference.update({"like_count": likes_count})
