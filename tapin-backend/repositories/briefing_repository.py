#
#  briefing_repository.py
#  TapIn Backend
#
#  Firestore repository for daily AI news briefings.
#  Collection: "daily_briefings"
#  Document ID: date string "YYYY-MM-DD" (one briefing per day)
#

import logging
from datetime import datetime, timezone

from services.firestore_client import get_firestore_client

logger = logging.getLogger(__name__)

COLLECTION = "daily_briefings"


class BriefingRepository:

    def get_briefing(self, date_str: str) -> dict | None:
        """Returns cached briefing for the given date, or None."""
        try:
            db = get_firestore_client()
            doc = db.collection(COLLECTION).document(date_str).get()
            if not doc.exists:
                return None
            data = doc.to_dict()
            # Convert Firestore timestamp to ISO string
            gen_at = data.get("generated_at")
            if hasattr(gen_at, "isoformat"):
                data["generated_at"] = gen_at.isoformat()
            elif hasattr(gen_at, "ToDatetime"):
                data["generated_at"] = gen_at.ToDatetime(tzinfo=timezone.utc).isoformat()
            return data
        except Exception as e:
            logger.error(f"Failed to fetch briefing for {date_str}: {e}")
            return None

    def save_briefing(self, date_str: str, briefing: dict) -> None:
        """Saves a briefing document keyed by date."""
        try:
            db = get_firestore_client()
            briefing["generated_at"] = datetime.now(tz=timezone.utc)
            db.collection(COLLECTION).document(date_str).set(briefing)
            logger.info(f"Saved daily briefing for {date_str}")
        except Exception as e:
            logger.error(f"Failed to save briefing for {date_str}: {e}")
            raise


# Singleton
briefing_repository = BriefingRepository()
