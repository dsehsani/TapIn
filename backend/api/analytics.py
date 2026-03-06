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
from services.analytics_service import (
    track_event, get_dau, get_dau_range,
    get_peak_dau, get_wau_mau, get_churn_risk,
    get_app_streak, get_weekly_cohorts, get_live_users, today_pacific,
)
from repositories.user_repository import user_repository

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
# MARK: - Peak DAU
# ------------------------------------------------------------------------------

@analytics_bp.route("/peak", methods=["GET"])
def peak():
    """Return the all-time peak DAU date and count."""
    token = request.args.get("token", "")
    if not DASHBOARD_TOKEN or token != DASHBOARD_TOKEN:
        return jsonify({"error": "Unauthorized"}), 401
    result = get_peak_dau()
    return jsonify({"success": True, "data": result}), 200


# ------------------------------------------------------------------------------
# MARK: - WAU / MAU
# ------------------------------------------------------------------------------

@analytics_bp.route("/wau-mau", methods=["GET"])
def wau_mau():
    """Return WAU, MAU, and DAU/MAU ratio."""
    token = request.args.get("token", "")
    if not DASHBOARD_TOKEN or token != DASHBOARD_TOKEN:
        return jsonify({"error": "Unauthorized"}), 401
    result = get_wau_mau()
    return jsonify({"success": True, "data": result}), 200


# ------------------------------------------------------------------------------
# MARK: - Live Users  (analytical only — no DAU impact)
# ------------------------------------------------------------------------------

@analytics_bp.route("/live", methods=["GET"])
def live():
    """Users active in the last 15 minutes based on event timestamps."""
    token = request.args.get("token", "")
    if not DASHBOARD_TOKEN or token != DASHBOARD_TOKEN:
        return jsonify({"error": "Unauthorized"}), 401
    return jsonify({"success": True, "data": get_live_users(window_minutes=15)}), 200


# ------------------------------------------------------------------------------
# MARK: - Churn / Streak / Cohorts  (analytical only — no DAU impact)
# ------------------------------------------------------------------------------

@analytics_bp.route("/churn", methods=["GET"])
def churn():
    token = request.args.get("token", "")
    if not DASHBOARD_TOKEN or token != DASHBOARD_TOKEN:
        return jsonify({"error": "Unauthorized"}), 401
    return jsonify({"success": True, "data": get_churn_risk()}), 200


@analytics_bp.route("/streak", methods=["GET"])
def streak():
    token = request.args.get("token", "")
    if not DASHBOARD_TOKEN or token != DASHBOARD_TOKEN:
        return jsonify({"error": "Unauthorized"}), 401
    return jsonify({"success": True, "data": get_app_streak()}), 200


@analytics_bp.route("/cohorts", methods=["GET"])
def cohorts():
    token = request.args.get("token", "")
    if not DASHBOARD_TOKEN or token != DASHBOARD_TOKEN:
        return jsonify({"error": "Unauthorized"}), 401
    return jsonify({"success": True, "data": get_weekly_cohorts()}), 200


# ------------------------------------------------------------------------------
# MARK: - Registered Users
# ------------------------------------------------------------------------------

@analytics_bp.route("/users", methods=["GET"])
def users():
    """Return all registered users for the dashboard user list."""
    token = request.args.get("token", "")
    if not DASHBOARD_TOKEN or token != DASHBOARD_TOKEN:
        return jsonify({"error": "Unauthorized"}), 401
    all_users = user_repository.get_all_users()
    return jsonify({"success": True, "data": all_users, "total": len(all_users)}), 200


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

    # Prepare 30-day range using Pacific time (matches iOS client date tracking)
    today_str = today_pacific()
    today = datetime.strptime(today_str, "%Y-%m-%d").date()
    start = today - timedelta(days=29)

    return render_template(
        "dashboard.html",
        start_date=start.isoformat(),
        end_date=today.isoformat(),
    )
