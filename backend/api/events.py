#
#  events.py
#  TapInApp - Backend Server
#
#  MARK: - Events API Blueprint
#
#  Endpoints:
#  GET  /api/events          - Returns all AI-processed campus events
#  POST /api/events/refresh  - Triggers re-fetch + AI processing (Cloud Scheduler)
#  GET  /api/events/health   - Health check
#

import os
import logging
from flask import Blueprint, jsonify, request
from services.event_processor_service import (
    get_events,
    refresh_events,
    refresh_events_background,
    is_refreshing,
)

logger = logging.getLogger(__name__)

events_bp = Blueprint("events", __name__, url_prefix="/api/events")


# ------------------------------------------------------------------------------
# MARK: - GET /api/events
# ------------------------------------------------------------------------------

@events_bp.route("", methods=["GET"])
def get_all_events():
    """
    Returns all AI-processed campus events from Firestore.

    If Firestore is empty (cold start / first deploy), triggers a background
    refresh and returns an empty list with refreshing=true so the client
    can poll or retry.

    Response (200):
        {
            "success": true,
            "events": [...],
            "count": 5,
            "refreshing": false
        }
    """
    try:
        events = get_events()

        refreshing = is_refreshing()

        # Cold start: Firestore is empty — kick off background refresh
        if not events and not refreshing:
            logger.info("Firestore empty — starting background refresh")
            refresh_events_background()
            refreshing = True

        return jsonify({
            "success": True,
            "events": events,
            "count": len(events),
            "refreshing": refreshing,
        }), 200

    except Exception as e:
        logger.error(f"GET /api/events failed: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ------------------------------------------------------------------------------
# MARK: - POST /api/events/refresh
# ------------------------------------------------------------------------------

@events_bp.route("/refresh", methods=["POST"])
def trigger_refresh():
    """
    Triggers a full re-fetch from Aggie Life + AI reprocessing.
    Called by Cloud Scheduler (hourly) or manually for admin/testing.

    Protected by X-Refresh-Secret header matching REFRESH_SECRET env var.
    If REFRESH_SECRET is not set, the endpoint is open (dev mode).

    Response (200):
        { "success": true, "result": { processed, skipped, errors, total_fetched } }
    """
    # Auth check
    secret = os.environ.get("REFRESH_SECRET", "")
    if secret:
        provided = request.headers.get("X-Refresh-Secret", "")
        if provided != secret:
            return jsonify({"success": False, "error": "Unauthorized"}), 401

    try:
        result = refresh_events()
        return jsonify({"success": True, "result": result}), 200
    except Exception as e:
        logger.error(f"POST /api/events/refresh failed: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ------------------------------------------------------------------------------
# MARK: - POST /api/events/backfill-locations
# ------------------------------------------------------------------------------

@events_bp.route("/backfill-locations", methods=["POST"])
def backfill_locations():
    """
    One-time backfill: scans existing events with location == "TBD" and
    uses Claude to extract a location from the description.
    """
    from repositories.event_repository import event_repository
    from services.claude_service import claude_service
    from services.firestore_client import get_firestore_client

    db = get_firestore_client()
    updated = 0
    skipped = 0
    errors = 0

    try:
        for doc in db.collection("processed_events").stream():
            data = doc.to_dict()
            # Skip events that already have aiLocation/webLocation or have a real location
            if data.get("aiLocation") or data.get("webLocation"):
                skipped += 1
                continue
            if data.get("location", "TBD") not in ("TBD", "", None):
                skipped += 1
                continue

            title = data.get("title", "")
            description = data.get("description", "")
            if not description.strip():
                skipped += 1
                continue

            try:
                # Step 1: scan description
                inferred = claude_service.extract_location_from_description(title, description)
                if inferred:
                    doc.reference.update({"aiLocation": inferred, "webLocation": None, "webLocationSource": None})
                    updated += 1
                    logger.info(f"Backfilled aiLocation for '{title}': {inferred}")
                else:
                    # Step 2: web search for club meeting place
                    organizer = data.get("organizerName") or data.get("clubAcronym")
                    if organizer:
                        web_result = claude_service.search_club_location(
                            organizer_name=data.get("organizerName", ""),
                            club_acronym=data.get("clubAcronym")
                        )
                        if web_result:
                            doc.reference.update({
                                "aiLocation": None,
                                "webLocation": web_result["location"],
                                "webLocationSource": web_result["source"],
                            })
                            updated += 1
                            logger.info(f"Backfilled webLocation for '{title}': {web_result['location']}")
                        else:
                            doc.reference.update({"aiLocation": None, "webLocation": None, "webLocationSource": None})
                            skipped += 1
                    else:
                        doc.reference.update({"aiLocation": None, "webLocation": None, "webLocationSource": None})
                        skipped += 1
            except Exception as e:
                errors += 1
                logger.error(f"Failed to backfill '{title}': {e}")

        return jsonify({
            "success": True,
            "updated": updated,
            "skipped": skipped,
            "errors": errors,
        }), 200

    except Exception as e:
        logger.error(f"Backfill failed: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ------------------------------------------------------------------------------
# MARK: - POST /api/events/backfill-confidence
# ------------------------------------------------------------------------------

@events_bp.route("/backfill-confidence", methods=["POST"])
def backfill_confidence():
    """
    One-time backfill: computes locationConfidence + locationConfidenceReason
    for every existing event in Firestore.
    """
    from repositories.event_repository import event_repository
    from services.claude_service import compute_location_confidence
    from services.firestore_client import get_firestore_client

    db = get_firestore_client()
    updated = 0
    skipped = 0
    errors = 0

    try:
        for doc in db.collection("processed_events").stream():
            data = doc.to_dict()

            # Skip events that already have a confidence score
            if data.get("locationConfidence") is not None:
                skipped += 1
                continue

            try:
                score, reason = compute_location_confidence(data)
                doc.reference.update({
                    "locationConfidence": score,
                    "locationConfidenceReason": reason,
                })
                updated += 1
                logger.info(f"Backfilled confidence for '{data.get('title')}': {score} — {reason}")
            except Exception as e:
                errors += 1
                logger.error(f"Failed to backfill confidence for '{data.get('title')}': {e}")

        return jsonify({
            "success": True,
            "updated": updated,
            "skipped": skipped,
            "errors": errors,
        }), 200

    except Exception as e:
        logger.error(f"Backfill confidence failed: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ------------------------------------------------------------------------------
# MARK: - POST /api/events/scrape-locations
# ------------------------------------------------------------------------------

@events_bp.route("/scrape-locations", methods=["POST"])
def scrape_private_locations():
    """
    Scrapes Aggie Life event pages using the authenticated session cookie
    to fill in private locations for events that currently have confidence=0.
    """
    from services.firestore_client import get_firestore_client
    from services.aggie_life_service import scrape_event_location
    from services.claude_service import compute_location_confidence

    db = get_firestore_client()
    updated = 0
    skipped = 0
    errors = 0
    cookie_expired = False

    try:
        for doc in db.collection("processed_events").stream():
            data = doc.to_dict()

            # Only target events with no location
            if (data.get("locationConfidence") or 0) != 0:
                skipped += 1
                continue

            event_url = data.get("eventURL")
            if not event_url:
                skipped += 1
                continue

            try:
                location = scrape_event_location(event_url)
                if location:
                    # Update the event with the scraped location as the iCal location
                    data["location"] = location
                    score, reason = compute_location_confidence(data)
                    doc.reference.update({
                        "location": location,
                        "locationConfidence": score,
                        "locationConfidenceReason": reason,
                    })
                    updated += 1
                    logger.info(f"Scraped location for '{data.get('title')}': {location} (conf={score})")
                else:
                    skipped += 1
            except Exception as e:
                errors += 1
                logger.error(f"Failed to scrape '{data.get('title')}': {e}")

        return jsonify({
            "success": True,
            "updated": updated,
            "skipped": skipped,
            "errors": errors,
        }), 200

    except Exception as e:
        logger.error(f"Scrape locations failed: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ------------------------------------------------------------------------------
# MARK: - POST /api/events/reset-tbd
# ------------------------------------------------------------------------------

@events_bp.route("/reset-tbd", methods=["POST"])
def reset_tbd_events():
    """
    Deletes processed events that still have location == 'TBD' (and no AI/web
    location) so the next refresh reprocesses them with the full pipeline.
    """
    from services.firestore_client import get_firestore_client

    db = get_firestore_client()
    deleted = 0

    try:
        for doc in db.collection("processed_events").stream():
            data = doc.to_dict()
            loc = data.get("location", "TBD")
            if loc in ("TBD", "", None) and not data.get("aiLocation") and not data.get("webLocation"):
                doc.reference.delete()
                deleted += 1

        return jsonify({"success": True, "deleted": deleted}), 200

    except Exception as e:
        logger.error(f"Reset TBD failed: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ------------------------------------------------------------------------------
# MARK: - GET /api/events/health
# ------------------------------------------------------------------------------

@events_bp.route("/health", methods=["GET"])
def health_check():
    """Health check including Firestore connectivity and event count."""
    try:
        from services.firestore_client import is_firestore_connected
        firestore_ok = is_firestore_connected()
        count = 0
        if firestore_ok:
            from repositories.event_repository import event_repository
            count = event_repository.count()

        return jsonify({
            "status": "healthy",
            "service": "campus-events",
            "firestore": "connected" if firestore_ok else "disconnected",
            "event_count": count,
            "refreshing": is_refreshing(),
        }), 200

    except Exception as e:
        return jsonify({
            "status": "degraded",
            "service": "campus-events",
            "error": str(e),
        }), 200
