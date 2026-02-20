#
#  event_repository.py
#  TapInApp - Backend Server
#
#  MARK: - Processed Events GCS Repository
#  Stores and retrieves AI-processed campus events as a single atomic JSON file.
#  Replaces per-document Firestore operations with one read / one write per refresh.
#
#  Bucket path: events/current.json
#  Schema: { events: [...], refreshed_at: str, count: int }
#

import logging
from datetime import datetime, timezone

from services.gcs_client import write_json, read_json

logger = logging.getLogger(__name__)

GCS_PATH = "events/current.json"


class EventRepository:

    # --------------------------------------------------------------------------
    # MARK: - Write
    # --------------------------------------------------------------------------

    def save_all_events(self, events: list[dict]) -> None:
        """
        Atomically replaces events/current.json with the full updated event list.
        All datetime values must already be ISO 8601 strings before calling this.
        """
        try:
            write_json(GCS_PATH, {
                "events":       events,
                "refreshed_at": datetime.now(tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                "count":        len(events),
            })
            logger.info(f"Saved {len(events)} events to GCS")
        except Exception as e:
            logger.error(f"Failed to save events: {e}")
            raise

    # --------------------------------------------------------------------------
    # MARK: - Read
    # --------------------------------------------------------------------------

    def get_all_events(self) -> list[dict]:
        """
        Returns all processed events sorted by startDate ascending.
        Returns [] if the file doesn't exist yet (cold start).
        """
        try:
            data = read_json(GCS_PATH)
            if data is None:
                return []
            events = data.get("events", [])
            events.sort(key=lambda e: e.get("startDate", ""))
            return events
        except Exception as e:
            logger.error(f"Failed to fetch events: {e}")
            return []

    def count(self) -> int:
        """Returns the number of processed events currently stored."""
        try:
            data = read_json(GCS_PATH)
            if data is None:
                return 0
            return data.get("count", 0)
        except Exception:
            return 0


# Singleton
event_repository = EventRepository()
