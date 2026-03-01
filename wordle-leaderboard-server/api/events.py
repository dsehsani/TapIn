#
#  events.py
#  TapInApp - Events Backend
#
#  Created by Claude for Darius Ehsani on 3/1/26.
#
#  MARK: - Events API Blueprint
#  Provides GET /api/events and GET /api/events/health endpoints.
#

from flask import Blueprint, jsonify, request

from services.events_service import events_service


# ------------------------------------------------------------------------------
# MARK: - Blueprint
# ------------------------------------------------------------------------------

events_bp = Blueprint("events", __name__, url_prefix="/api/events")


# ------------------------------------------------------------------------------
# MARK: - GET /api/events
# ------------------------------------------------------------------------------

@events_bp.route("", methods=["GET"])
@events_bp.route("/", methods=["GET"])
def get_events():
    """
    Fetch all upcoming campus events.

    Query Parameters:
        refresh (optional): Set to "true" to bypass cache and re-fetch feeds.

    Response:
        {
            "success": true,
            "events": [ ... ]
        }
    """
    try:
        force_refresh = request.args.get("refresh", "").lower() == "true"
        events = events_service.get_events(force_refresh=force_refresh)

        return jsonify({
            "success": True,
            "events": events
        })

    except Exception as e:
        print(f"[EventsAPI] Error fetching events: {e}")
        return jsonify({
            "success": False,
            "error": "Failed to fetch events",
            "events": []
        }), 500


# ------------------------------------------------------------------------------
# MARK: - GET /api/events/health
# ------------------------------------------------------------------------------

@events_bp.route("/health", methods=["GET"])
def events_health():
    """
    Health check for the events service.

    Response:
        {
            "status": "healthy",
            "service": "events"
        }
    """
    return jsonify({
        "status": "healthy",
        "service": "events"
    })
