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
from datetime import datetime, timedelta, timezone
from typing import Dict, List, Optional
from zoneinfo import ZoneInfo
from services.firestore_client import get_firestore_client

PACIFIC = ZoneInfo("America/Los_Angeles")

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
            "user_ids": list(users),
        }
    except Exception as e:
        logger.error(f"Failed to fetch DAU for {date}: {e}")
        return {
            "date": date,
            "unique_users": 0,
            "total_events": 0,
            "actions": {},
        }


def today_pacific() -> str:
    """Return today's date string in Pacific time (matches iOS client)."""
    return datetime.now(PACIFIC).strftime("%Y-%m-%d")


def get_unique_users_in_range(start: str, end: str) -> int:
    """Count unique users across a date range (for WAU/MAU)."""
    try:
        start_date = datetime.strptime(start, "%Y-%m-%d")
        end_date = datetime.strptime(end, "%Y-%m-%d")
        db = get_firestore_client()
        all_users: set = set()
        current = start_date
        while current <= end_date:
            date_str = current.strftime("%Y-%m-%d")
            docs = (
                db.collection(DAU_COLLECTION)
                  .document(date_str)
                  .collection("events")
                  .stream()
            )
            for doc in docs:
                data = doc.to_dict()
                all_users.add(data.get("user_id", ""))
            current += timedelta(days=1)
        return len(all_users)
    except Exception as e:
        logger.error(f"Failed to compute unique users in range: {e}")
        return 0


def get_wau_mau() -> Dict:
    """
    Compute Weekly Active Users, Monthly Active Users, and DAU/MAU ratio.
    Uses Pacific time to match iOS client.
    """
    today_str = today_pacific()
    today = datetime.strptime(today_str, "%Y-%m-%d")

    week_start = (today - timedelta(days=6)).strftime("%Y-%m-%d")
    month_start = (today - timedelta(days=29)).strftime("%Y-%m-%d")

    dau = get_dau(today_str)["unique_users"]
    wau = get_unique_users_in_range(week_start, today_str)
    mau = get_unique_users_in_range(month_start, today_str)

    dau_mau_ratio = round((dau / mau * 100), 1) if mau > 0 else 0.0

    return {
        "dau": dau,
        "wau": wau,
        "mau": mau,
        "dau_mau_ratio": dau_mau_ratio,
    }


def get_live_users(window_minutes: int = 15) -> Dict:
    """
    Count users who triggered any event in the last `window_minutes` minutes.
    Uses the UTC timestamp stored on each event doc.
    Does NOT affect DAU counting — purely observational.
    """
    try:
        db = get_firestore_client()
        cutoff = (datetime.utcnow() - timedelta(minutes=window_minutes)).isoformat()
        today_str = today_pacific()

        docs = (
            db.collection(DAU_COLLECTION)
              .document(today_str)
              .collection("events")
              .where("timestamp", ">=", cutoff)
              .stream()
        )

        users = set()
        for doc in docs:
            data = doc.to_dict()
            users.add(data.get("user_id", ""))

        return {
            "live_count": len(users),
            "window_minutes": window_minutes,
            "as_of": datetime.utcnow().isoformat(),
        }
    except Exception as e:
        logger.error(f"Failed to get live users: {e}")
        return {"live_count": 0, "window_minutes": window_minutes, "as_of": datetime.utcnow().isoformat()}


def get_churn_risk() -> Dict:
    """
    Users active 8–30 days ago but NOT in the last 7 days.
    These are users who engaged recently but have gone quiet — at risk of churning.
    Does NOT affect DAU counting.
    """
    today = datetime.strptime(today_pacific(), "%Y-%m-%d")

    recent_start = (today - timedelta(days=6)).strftime("%Y-%m-%d")
    recent_users: set = set()
    for d in get_dau_range(recent_start, today.strftime("%Y-%m-%d")):
        recent_users.update(d.get("user_ids", []))

    older_start = (today - timedelta(days=29)).strftime("%Y-%m-%d")
    older_end   = (today - timedelta(days=7)).strftime("%Y-%m-%d")
    older_users: set = set()
    for d in get_dau_range(older_start, older_end):
        older_users.update(d.get("user_ids", []))

    at_risk = older_users - recent_users
    return {
        "at_risk_count": len(at_risk),
        "recent_active": len(recent_users),
        "total_tracked": len(recent_users | older_users),
    }


def get_app_streak() -> Dict:
    """
    Consecutive calendar days (Pacific) where at least 1 user was active.
    Purely observational — does not affect DAU.
    """
    today = datetime.strptime(today_pacific(), "%Y-%m-%d")
    streak = 0
    current = today
    while True:
        result = get_dau(current.strftime("%Y-%m-%d"))
        if result["unique_users"] > 0:
            streak += 1
            current -= timedelta(days=1)
        else:
            break
    since = (current + timedelta(days=1)).strftime("%Y-%m-%d") if streak > 0 else None
    return {"streak": streak, "since": since}


def get_weekly_cohorts() -> List[Dict]:
    """
    4-week retention cohort table.
    For each of the last 4 weeks, shows what % of that week's users
    came back in each subsequent week. Purely analytical — no DAU impact.
    """
    today = datetime.strptime(today_pacific(), "%Y-%m-%d")

    # Build 4 weekly buckets (oldest first)
    weeks = []
    for i in range(4, 0, -1):
        week_end   = today - timedelta(days=(i - 1) * 7)
        week_start = week_end - timedelta(days=6)
        label = f"{week_start.strftime('%b %d')}–{week_end.strftime('%b %d')}"
        user_ids: set = set()
        for d in get_dau_range(week_start.strftime("%Y-%m-%d"), week_end.strftime("%Y-%m-%d")):
            user_ids.update(d.get("user_ids", []))
        weeks.append({"label": label, "user_ids": user_ids, "count": len(user_ids)})

    cohorts = []
    for i, week in enumerate(weeks):
        retention = []
        for j in range(i, len(weeks)):
            overlap = len(week["user_ids"] & weeks[j]["user_ids"])
            pct = round(overlap / week["count"] * 100) if week["count"] > 0 else 0
            retention.append({"week_offset": j - i, "users": overlap, "pct": pct})
        cohorts.append({"label": week["label"], "size": week["count"], "retention": retention})

    return cohorts


def get_peak_dau() -> Dict:
    """
    Scan all dates since app launch to find the all-time peak DAU day.

    Firestore dau_events/{date} docs are implicitly created via subcollection
    writes, so streaming the collection returns nothing. Instead we scan the
    full date range from launch to today.

    Returns:
        {
            "date": "2026-02-14",
            "unique_users": 87
        }
    """
    try:
        # App launched ~2026-02-01; scan from there to today (Pacific)
        launch_date = datetime(2026, 2, 1)
        today = datetime.strptime(today_pacific(), "%Y-%m-%d")

        peak_users = 0
        peak_date = None

        current = launch_date
        while current <= today:
            date_str = current.strftime("%Y-%m-%d")
            result = get_dau(date_str)
            if result["unique_users"] > peak_users:
                peak_users = result["unique_users"]
                peak_date = date_str
            current += timedelta(days=1)

        return {"date": peak_date, "unique_users": peak_users}
    except Exception as e:
        logger.error(f"Failed to compute peak DAU: {e}")
        return {"date": None, "unique_users": 0}


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
