#
#  analytics.py
#  TapInApp - Backend Server
#
#  MARK: - Analytics API Blueprint
#  Endpoints for DAU event tracking and querying.
#
#  Routes:
#    POST /api/analytics/track   — record a DAU event
#    GET  /api/analytics/dau     — query DAU (single date or range)
#    GET  /api/analytics/health  — health check
#    GET  /api/analytics/dashboard — admin dashboard (Chart.js)
#

import os
from datetime import datetime, timedelta
from flask import Blueprint, request, jsonify, render_template
from services.analytics_service import track_event, get_dau, get_dau_range

analytics_bp = Blueprint("analytics", __name__, url_prefix="/api/analytics")

# Dashboard access token (set via environment variable)
DASHBOARD_TOKEN = os.environ.get("DASHBOARD_TOKEN", "")


# ------------------------------------------------------------------------------
# MARK: - Track Event
# ------------------------------------------------------------------------------

@analytics_bp.route("/track", methods=["POST"])
def track():
    """
    Record a DAU event.

    Request JSON:
        {
            "user_id": "abc123",
            "action": "article_read",
            "date": "2026-03-03"
        }
    """
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"success": False, "error": "JSON body required"}), 400

    user_id = data.get("user_id")
    action = data.get("action")
    date = data.get("date")

    if not all([user_id, action, date]):
        return jsonify({"success": False, "error": "Missing required fields"}), 400

    success = track_event(user_id, action, date)
    if not success:
        return jsonify({"success": False, "error": "Invalid action or date"}), 400

    return jsonify({"success": True}), 200


# ------------------------------------------------------------------------------
# MARK: - Query DAU
# ------------------------------------------------------------------------------

@analytics_bp.route("/dau", methods=["GET"])
def dau():
    """
    Query DAU metrics.

    Query params:
        ?date=2026-03-03           — single day
        ?start=2026-02-01&end=2026-03-03  — date range
    """
    date = request.args.get("date")
    start = request.args.get("start")
    end = request.args.get("end")

    if date:
        result = get_dau(date)
        return jsonify({"success": True, "data": result}), 200
    elif start and end:
        results = get_dau_range(start, end)
        return jsonify({"success": True, "data": results}), 200
    else:
        return jsonify({"success": False, "error": "Provide ?date= or ?start=&end="}), 400


# ------------------------------------------------------------------------------
# MARK: - Health Check
# ------------------------------------------------------------------------------

@analytics_bp.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok", "service": "analytics"}), 200


# ------------------------------------------------------------------------------
# MARK: - Admin Dashboard
# ------------------------------------------------------------------------------

@analytics_bp.route("/dashboard", methods=["GET"])
def dashboard():
    """
    Render the admin DAU dashboard.
    Protected by a query-param token.
    """
    token = request.args.get("token", "")
    if not DASHBOARD_TOKEN or token != DASHBOARD_TOKEN:
        return jsonify({"error": "Unauthorized"}), 401

    # Prepare 30-day range for the chart
    today = datetime.utcnow().date()
    start = today - timedelta(days=29)

    return render_template(
        "dashboard.html",
        start_date=start.isoformat(),
        end_date=today.isoformat(),
    )
