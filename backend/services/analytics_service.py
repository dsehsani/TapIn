#
#  analytics_service.py
#  TapInApp - Backend Server
#
#  MARK: - Analytics Service
#  Tracks Daily Active Users (DAU) via Firestore.
#  Each event is stored with a deterministic doc ID for server-side dedup.
#
#  Firestore Structure:
#  - Collection: dau_events / {date} / events / {user_id}_{action}
#

import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional
from services.firestore_client import get_firestore_client

logger = logging.getLogger(__name__)

# Valid actions the client may send
VALID_ACTIONS = {
    "article_read",
    "event_viewed",
    "wordle_played",
    "echo_played",
    "pipes_played",
}

DAU_COLLECTION = "dau_events"


# ------------------------------------------------------------------------------
# MARK: - Track Event
# ------------------------------------------------------------------------------

def track_event(user_id: str, action: str, date: str) -> bool:
    """
    Record a single DAU event.

    Uses a deterministic document ID (`{user_id}_{action}`) so duplicate
    writes from the same user+action+day are idempotent.

    Args:
        user_id: Unique user identifier (backend token or SMS user ID)
        action:  One of VALID_ACTIONS
        date:    Date string in YYYY-MM-DD format

    Returns:
        True on success, False on validation failure
    """
    if action not in VALID_ACTIONS:
        logger.warning(f"Invalid analytics action: {action}")
        return False

    # Basic date validation
    try:
        datetime.strptime(date, "%Y-%m-%d")
    except ValueError:
        logger.warning(f"Invalid date format: {date}")
        return False

    doc_id = f"{user_id}_{action}"

    try:
        db = get_firestore_client()
        doc_ref = (
            db.collection(DAU_COLLECTION)
              .document(date)
              .collection("events")
              .document(doc_id)
        )
        doc_ref.set({
            "user_id": user_id,
            "action": action,
            "date": date,
            "timestamp": datetime.utcnow().isoformat(),
        })
        logger.info(f"DAU event recorded: {doc_id} on {date}")
        return True
    except Exception as e:
        logger.error(f"Failed to record DAU event: {e}")
        return False


# ------------------------------------------------------------------------------
# MARK: - Query DAU
# ------------------------------------------------------------------------------

def get_dau(date: str) -> Dict:
    """
    Get DAU metrics for a single date.

    Returns:
        {
            "date": "2026-03-03",
            "unique_users": 42,
            "total_events": 58,
            "actions": { "article_read": 30, "wordle_played": 20, ... }
        }
    """
    try:
        db = get_firestore_client()
        docs = (
            db.collection(DAU_COLLECTION)
              .document(date)
              .collection("events")
              .stream()
        )

        users = set()
        actions: Dict[str, int] = {}
        total = 0

        for doc in docs:
            data = doc.to_dict()
            users.add(data.get("user_id", ""))
            action = data.get("action", "unknown")
            actions[action] = actions.get(action, 0) + 1
            total += 1

        return {
            "date": date,
            "unique_users": len(users),
            "total_events": total,
            "actions": actions,
        }
    except Exception as e:
        logger.error(f"Failed to fetch DAU for {date}: {e}")
        return {
            "date": date,
            "unique_users": 0,
            "total_events": 0,
            "actions": {},
        }


def get_dau_range(start: str, end: str) -> List[Dict]:
    """
    Get daily DAU counts for a date range (inclusive).

    Args:
        start: Start date (YYYY-MM-DD)
        end:   End date (YYYY-MM-DD)

    Returns:
        List of per-day DAU dicts, sorted ascending by date.
    """
    try:
        start_date = datetime.strptime(start, "%Y-%m-%d")
        end_date = datetime.strptime(end, "%Y-%m-%d")
    except ValueError:
        return []

    results = []
    current = start_date
    while current <= end_date:
        date_str = current.strftime("%Y-%m-%d")
        results.append(get_dau(date_str))
        current += timedelta(days=1)

    return results
