#
#  event_processor_service.py
#  TapInApp - Backend Server
#
#  MARK: - Event Processor Service
#  Orchestrates the full pipeline:
#  1. Load existing events from GCS (one atomic read)
#  2. Fetch fresh events from Aggie Life iCal
#  3. For each event already in GCS with AI content, reuse it (skip re-processing)
#  4. For new events, generate AI summary + bullet points via Claude
#  5. Filter out past events, mirror images to GCS
#  6. Atomically write the full updated list back to GCS (one write)
#
#  This replaces the previous per-document Firestore approach:
#  old: N reads + N writes (one per event)
#  new: 1 read + 1 write for the entire event list
#
#  Called by:
#  - POST /api/events/refresh  (Cloud Scheduler, admin)
#  - GET  /api/events          (lazy init if GCS file is empty)
#

import logging
import threading
from datetime import datetime, timezone

from services import aggie_life_service
from services.claude_service import claude_service
from services.image_mirror_service import mirror_event_image
from repositories.event_repository import event_repository

logger = logging.getLogger(__name__)

# Prevents multiple concurrent refreshes (e.g., during cold-start with multiple workers)
_refresh_lock = threading.Lock()
_is_refreshing = False


def refresh_events() -> dict:
    """
    Full pipeline: fetch → AI enrich → mirror images → atomic GCS write.
    Returns a summary dict: { processed, skipped, errors, total_fetched, removed_past }
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
    """Returns all processed events from GCS."""
    return event_repository.get_all_events()


# ------------------------------------------------------------------------------
# MARK: - Internal Pipeline
# ------------------------------------------------------------------------------

def _run_refresh() -> dict:
    logger.info("Starting event refresh pipeline")
    now = datetime.now(tz=timezone.utc)
    processed = 0
    skipped = 0
    errors = 0

    # Step 1: Load the current event list from GCS (one read)
    existing_events = event_repository.get_all_events()

    # Build a lookup map: event_id → enriched event dict (for idempotency)
    # Only keep events that already have AI content
    existing_map = {
        e["id"]: e
        for e in existing_events
        if e.get("aiSummary") and e.get("aiBulletPoints")
    }
    logger.info(f"Loaded {len(existing_events)} existing events ({len(existing_map)} with AI content)")

    # Step 2: Fetch fresh events from Aggie Life (next 7 days)
    try:
        raw_events = aggie_life_service.fetch_events()
    except Exception as e:
        logger.error(f"Failed to fetch Aggie Life events: {e}")
        return {"error": str(e), "processed": 0, "skipped": 0, "errors": 1, "removed_past": 0}

    logger.info(f"Fetched {len(raw_events)} events from Aggie Life")

    # Step 3: For each fresh event, reuse existing AI content or generate new
    final_events = []
    for event in raw_events:
        event_id = event["id"]

        # Filter out past events (aggie_life_service filters to next 7 days but
        # be defensive in case of timezone edge cases)
        start = event.get("startDate", "")
        if isinstance(start, str) and start:
            try:
                start_dt = datetime.fromisoformat(start.replace("Z", "+00:00"))
                if start_dt < now:
                    logger.debug(f"Skipping past event: {event.get('title')}")
                    continue
            except ValueError:
                pass  # Unparseable date — keep the event

        # Reuse existing AI content if already processed
        if event_id in existing_map:
            enriched = existing_map[event_id]
            final_events.append(enriched)
            skipped += 1
            logger.debug(f"Reusing AI content for: {event.get('title')}")
            continue

        # New event — generate AI summary + bullet points
        try:
            description = event.get("description", "")
            title = event.get("title", "")

            event["aiSummary"] = claude_service.summarize_event_internal(description)
            event["aiBulletPoints"] = claude_service.generate_bullet_points(title, description)
            event["processedAt"] = now.strftime("%Y-%m-%dT%H:%M:%SZ")

            # Mirror the event image to GCS so the URL is stable
            original_image = event.get("imageURL")
            event["imageURL"] = mirror_event_image(event_id, original_image)

            final_events.append(event)
            processed += 1
            logger.info(f"Processed new event: {title}")

        except Exception as e:
            errors += 1
            logger.error(f"Failed to process event '{event.get('title')}': {e}")
            # Include the event without AI content rather than dropping it
            final_events.append(event)

    # Count how many events from the old list were not in the fresh feed (past/removed)
    fresh_ids = {e["id"] for e in raw_events}
    removed_past = len([e for e in existing_events if e["id"] not in fresh_ids])

    # Step 4: Atomically write the full updated list to GCS (one write)
    event_repository.save_all_events(final_events)

    result = {
        "processed":     processed,
        "skipped":       skipped,
        "removed_past":  removed_past,
        "errors":        errors,
        "total_fetched": len(raw_events),
        "completed_at":  now.strftime("%Y-%m-%dT%H:%M:%SZ"),
    }
    logger.info(f"Refresh complete: {result}")
    return result
