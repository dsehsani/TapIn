#
#  event_processor_service.py
#  TapInApp - Backend Server
#
#  MARK: - Event Processor Service
#  Orchestrates the full pipeline:
#  1. Fetch events from Aggie Life iCal
#  2. For each new event, generate AI summary + bullet points via Claude
#  3. Store processed events in Firestore
#
#  Called by:
#  - POST /api/events/refresh  (Cloud Scheduler, admin)
#  - GET  /api/events          (lazy init if Firestore is empty)
#

import logging
import threading
from datetime import datetime, timezone

from services import aggie_life_service
from services.claude_service import claude_service
from repositories.event_repository import event_repository

logger = logging.getLogger(__name__)

# Prevents multiple concurrent refreshes (e.g., during cold-start with multiple workers)
_refresh_lock = threading.Lock()
_is_refreshing = False


def refresh_events() -> dict:
    """
    Full pipeline: fetch → AI enrich → store in Firestore.

    Returns a summary dict: { processed, skipped, errors, total_fetched }
    """
    global _is_refreshing

    if not _refresh_lock.acquire(blocking=False):
        logger.info("Refresh already in progress, skipping.")
        return {"skipped_reason": "refresh_in_progress"}

    _is_refreshing = True
    try:
        return _run_refresh()
    finally:
        _is_refreshing = False
        _refresh_lock.release()


def refresh_events_background() -> None:
    """Starts refresh_events() in a daemon background thread."""
    t = threading.Thread(target=refresh_events, daemon=True)
    t.start()


def is_refreshing() -> bool:
    return _is_refreshing


def get_events() -> list[dict]:
    """Returns all processed events from Firestore."""
    return event_repository.get_all_events()


# ------------------------------------------------------------------------------
# MARK: - Internal Pipeline
# ------------------------------------------------------------------------------

def _run_refresh() -> dict:
    logger.info("Starting event refresh pipeline")
    processed = 0
    skipped = 0
    errors = 0

    # Step 1: Remove any events whose startDate has already passed
    removed = event_repository.delete_past_events()
    logger.info(f"Removed {removed} past events from Firestore")

    # Step 2: Fetch raw events from Aggie Life
    try:
        raw_events = aggie_life_service.fetch_events()
    except Exception as e:
        logger.error(f"Failed to fetch Aggie Life events: {e}")
        return {"error": str(e), "processed": 0, "skipped": 0, "errors": 1}

    logger.info(f"Fetched {len(raw_events)} events from Aggie Life")

    # Step 2: For each event, generate AI content and store
    for event in raw_events:
        doc_id = event["id"]

        # Skip if already processed and stored
        if event_repository.event_exists(doc_id):
            skipped += 1
            logger.debug(f"Skipping already-processed event: {event['title']}")
            continue

        try:
            description = event.get("description", "")
            title = event.get("title", "")

            # Generate AI summary (short sentence for card view)
            event["aiSummary"] = claude_service.summarize_event_internal(description)

            # Generate AI bullet points (for detail view)
            event["aiBulletPoints"] = claude_service.generate_bullet_points(title, description)

            # Timestamp when processed
            event["processedAt"] = datetime.now(tz=timezone.utc)

            event_repository.save_event(event)
            processed += 1
            logger.info(f"Processed: {title}")

        except Exception as e:
            errors += 1
            logger.error(f"Failed to process event '{event.get('title')}': {e}")

    result = {
        "processed": processed,
        "skipped": skipped,
        "removed_past": removed,
        "errors": errors,
        "total_fetched": len(raw_events),
        "completed_at": datetime.now(tz=timezone.utc).isoformat(),
    }
    logger.info(f"Refresh complete: {result}")
    return result
