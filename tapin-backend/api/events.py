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
