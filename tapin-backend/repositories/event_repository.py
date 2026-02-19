#
#  event_repository.py
#  TapInApp - Backend Server
#
#  MARK: - Processed Events Firestore Repository
#  Stores and retrieves AI-processed campus events.
#  Document ID is a deterministic UUID derived from event title + date,
#  so the same event always maps to the same document (idempotent writes).
#

import logging
from datetime import datetime, timezone

from services.firestore_client import get_firestore_client

logger = logging.getLogger(__name__)

COLLECTION = "processed_events"


class EventRepository:

    # --------------------------------------------------------------------------
    # MARK: - Write
    # --------------------------------------------------------------------------

    def save_event(self, event: dict) -> None:
        """
        Upserts a processed event document into Firestore.
        The document ID is event["id"] (deterministic UUID).
        """
        try:
            db = get_firestore_client()
            doc_id = event["id"]
            db.collection(COLLECTION).document(doc_id).set(event)
            logger.info(f"Saved event: {event.get('title', doc_id)}")
        except Exception as e:
            logger.error(f"Failed to save event {event.get('id')}: {e}")
            raise

    # --------------------------------------------------------------------------
    # MARK: - Read
    # --------------------------------------------------------------------------

    def get_all_events(self) -> list[dict]:
        """
        Returns all processed events, sorted by startDate ascending.
        Converts Firestore Timestamps back to ISO 8601 strings for JSON serialization.
        """
        try:
            db = get_firestore_client()
            docs = db.collection(COLLECTION).stream()
            events = []
            for doc in docs:
                data = doc.to_dict()
                data = _convert_timestamps(data)
                events.append(data)
            events.sort(key=lambda e: e.get("startDate", ""))
            return events
        except Exception as e:
            logger.error(f"Failed to fetch events: {e}")
            return []

    def event_exists(self, doc_id: str) -> bool:
        """Returns True if a processed event document already exists in Firestore."""
        try:
            db = get_firestore_client()
            doc = db.collection(COLLECTION).document(doc_id).get()
            return doc.exists
        except Exception as e:
            logger.error(f"Failed to check event existence {doc_id}: {e}")
            return False

    def count(self) -> int:
        """Returns the number of processed events in Firestore."""
        try:
            db = get_firestore_client()
            docs = list(db.collection(COLLECTION).stream())
            return len(docs)
        except Exception:
            return 0

    def delete_past_events(self) -> int:
        """
        Deletes events whose startDate has already passed.
        Called during each refresh so Firestore only ever holds the current week.
        Returns the number of events deleted.
        """
        now = datetime.now(tz=timezone.utc)
        deleted = 0
        try:
            db = get_firestore_client()
            for doc in db.collection(COLLECTION).stream():
                data = doc.to_dict()
                start = data.get("startDate")

                # Firestore stores as Timestamp or datetime
                if hasattr(start, "ToDatetime"):
                    start = start.ToDatetime(tzinfo=timezone.utc)
                elif isinstance(start, datetime) and start.tzinfo is None:
                    start = start.replace(tzinfo=timezone.utc)

                if isinstance(start, datetime) and start < now:
                    doc.reference.delete()
                    deleted += 1
                    logger.info(f"Deleted past event: {data.get('title')}")

        except Exception as e:
            logger.error(f"Failed to delete past events: {e}")

        return deleted

    def delete_all(self) -> None:
        """Deletes all processed events. For testing/reset only."""
        try:
            db = get_firestore_client()
            for doc in db.collection(COLLECTION).stream():
                doc.reference.delete()
            logger.info("Deleted all processed events")
        except Exception as e:
            logger.error(f"Failed to delete events: {e}")


# ------------------------------------------------------------------------------
# MARK: - Helpers
# ------------------------------------------------------------------------------

def _convert_timestamps(data: dict) -> dict:
    """
    Converts Firestore Timestamp objects and datetime objects to ISO 8601 strings.
    Handles nested values.
    """
    result = {}
    for key, value in data.items():
        if hasattr(value, "isoformat"):
            # datetime or Firestore DatetimeWithNanoseconds
            dt = value
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=timezone.utc)
            result[key] = dt.strftime("%Y-%m-%dT%H:%M:%SZ")
        elif hasattr(value, "ToDatetime"):
            # Firestore Timestamp
            dt = value.ToDatetime(tzinfo=timezone.utc)
            result[key] = dt.strftime("%Y-%m-%dT%H:%M:%SZ")
        elif value is None:
            result[key] = None
        else:
            result[key] = value
    return result


# Singleton
event_repository = EventRepository()
