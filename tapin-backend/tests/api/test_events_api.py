"""
test_events_api.py — Flask client tests for api/events.py

All service/repository calls are patched so no real GCS or network calls happen.
"""

import pytest
from unittest.mock import patch, MagicMock

FUTURE = "2099-12-31T18:00:00Z"

EVENT = {
    "id": "b" * 36,
    "title": "Test Event",
    "description": "A test campus event.",
    "startDate": FUTURE,
    "endDate": FUTURE,
    "location": "ARC",
    "isOfficial": True,
    "imageURL": None,
    "organizerName": "Campus Rec",
    "aiSummary": "Fun event at the ARC.",
    "aiBulletPoints": ["🏀 Basketball", "🎉 Fun"],
}


# ---------------------------------------------------------------------------
# MARK: - GET /api/events
# ---------------------------------------------------------------------------

class TestGetEvents:

    def test_returns_events_from_gcs(self, client):
        with patch("api.events.get_events", return_value=[EVENT]), \
             patch("api.events.is_refreshing", return_value=False):
            resp = client.get("/api/events")

        data = resp.get_json()
        assert resp.status_code == 200
        assert data["success"] is True
        assert data["count"] == 1
        assert data["refreshing"] is False
        assert len(data["events"]) == 1

    def test_cold_start_empty_triggers_background_refresh(self, client):
        with patch("api.events.get_events", return_value=[]), \
             patch("api.events.is_refreshing", return_value=False), \
             patch("api.events.refresh_events_background") as mock_bg:
            resp = client.get("/api/events")

        data = resp.get_json()
        assert resp.status_code == 200
        assert data["events"] == []
        assert data["refreshing"] is True
        mock_bg.assert_called_once()

    def test_cold_start_already_refreshing_does_not_double_refresh(self, client):
        with patch("api.events.get_events", return_value=[]), \
             patch("api.events.is_refreshing", return_value=True), \
             patch("api.events.refresh_events_background") as mock_bg:
            client.get("/api/events")

        mock_bg.assert_not_called()

    def test_events_populated_refreshing_false_no_background_started(self, client):
        with patch("api.events.get_events", return_value=[EVENT]), \
             patch("api.events.is_refreshing", return_value=False), \
             patch("api.events.refresh_events_background") as mock_bg:
            resp = client.get("/api/events")

        mock_bg.assert_not_called()
        assert resp.get_json()["refreshing"] is False

    def test_get_events_exception_returns_500(self, client):
        with patch("api.events.get_events", side_effect=Exception("GCS down")):
            resp = client.get("/api/events")

        data = resp.get_json()
        assert resp.status_code == 500
        assert data["success"] is False
        assert "error" in data

    def test_response_contains_all_required_fields(self, client):
        with patch("api.events.get_events", return_value=[EVENT]), \
             patch("api.events.is_refreshing", return_value=False):
            resp = client.get("/api/events")

        data = resp.get_json()
        for field in ["success", "events", "count", "refreshing"]:
            assert field in data, f"Field '{field}' missing from /api/events response"

    def test_count_matches_events_length(self, client):
        events = [EVENT, dict(EVENT)]
        events[1] = dict(EVENT)
        events[1]["id"] = "c" * 36

        with patch("api.events.get_events", return_value=events), \
             patch("api.events.is_refreshing", return_value=False):
            resp = client.get("/api/events")

        data = resp.get_json()
        assert data["count"] == len(data["events"])

    def test_refreshing_true_when_background_refresh_running(self, client):
        with patch("api.events.get_events", return_value=[EVENT]), \
             patch("api.events.is_refreshing", return_value=True):
            resp = client.get("/api/events")

        assert resp.get_json()["refreshing"] is True


# ---------------------------------------------------------------------------
# MARK: - POST /api/events/refresh
# ---------------------------------------------------------------------------

class TestTriggerRefresh:

    RESULT = {
        "processed": 3,
        "skipped": 2,
        "removed_past": 1,
        "errors": 0,
        "total_fetched": 5,
        "completed_at": "2026-02-19T12:00:00Z",
    }

    def test_no_secret_set_allows_unauthenticated(self, client, monkeypatch):
        monkeypatch.delenv("REFRESH_SECRET", raising=False)
        with patch("api.events.refresh_events", return_value=self.RESULT):
            resp = client.post("/api/events/refresh")
        assert resp.status_code == 200

    def test_valid_secret_returns_200(self, client, monkeypatch):
        monkeypatch.setenv("REFRESH_SECRET", "my-secret")
        with patch("api.events.refresh_events", return_value=self.RESULT):
            resp = client.post("/api/events/refresh",
                               headers={"X-Refresh-Secret": "my-secret"})
        assert resp.status_code == 200
        data = resp.get_json()
        assert data["success"] is True
        assert data["result"] == self.RESULT

    def test_wrong_secret_returns_401(self, client, monkeypatch):
        monkeypatch.setenv("REFRESH_SECRET", "my-secret")
        resp = client.post("/api/events/refresh",
                           headers={"X-Refresh-Secret": "wrong"})
        assert resp.status_code == 401
        assert resp.get_json()["success"] is False

    def test_missing_secret_header_returns_401(self, client, monkeypatch):
        monkeypatch.setenv("REFRESH_SECRET", "my-secret")
        resp = client.post("/api/events/refresh")
        assert resp.status_code == 401

    def test_result_dict_in_response(self, client, monkeypatch):
        monkeypatch.delenv("REFRESH_SECRET", raising=False)
        with patch("api.events.refresh_events", return_value=self.RESULT):
            resp = client.post("/api/events/refresh")

        data = resp.get_json()
        assert "result" in data
        for key in ["processed", "skipped", "errors", "total_fetched"]:
            assert key in data["result"]

    def test_refresh_exception_returns_500(self, client, monkeypatch):
        monkeypatch.delenv("REFRESH_SECRET", raising=False)
        with patch("api.events.refresh_events", side_effect=Exception("pipeline crash")):
            resp = client.post("/api/events/refresh")

        data = resp.get_json()
        assert resp.status_code == 500
        assert data["success"] is False

    def test_refresh_returns_skip_reason_for_in_progress(self, client, monkeypatch):
        monkeypatch.delenv("REFRESH_SECRET", raising=False)
        skip_result = {"skipped_reason": "refresh_in_progress"}
        with patch("api.events.refresh_events", return_value=skip_result):
            resp = client.post("/api/events/refresh")

        data = resp.get_json()
        assert resp.status_code == 200
        assert data["result"]["skipped_reason"] == "refresh_in_progress"


# ---------------------------------------------------------------------------
# MARK: - GET /api/events/health
# ---------------------------------------------------------------------------

class TestEventsHealth:

    def test_gcs_connected_returns_healthy(self, client):
        with patch("services.gcs_client.is_gcs_connected", return_value=True), \
             patch("repositories.event_repository.event_repository") as repo, \
             patch("api.events.is_refreshing", return_value=False):
            repo.count.return_value = 7

            resp = client.get("/api/events/health")

        data = resp.get_json()
        assert resp.status_code == 200
        assert data["status"] == "healthy"
        assert data["gcs"] == "connected"
        assert data["storage"] == "gcs"
        assert data["service"] == "campus-events"

    def test_event_count_present_when_gcs_connected(self, client):
        with patch("services.gcs_client.is_gcs_connected", return_value=True), \
             patch("repositories.event_repository.event_repository") as repo, \
             patch("api.events.is_refreshing", return_value=False):
            repo.count.return_value = 12

            resp = client.get("/api/events/health")

        data = resp.get_json()
        assert data["event_count"] == 12

    def test_gcs_disconnected_returns_200_with_disconnected(self, client):
        with patch("services.gcs_client.is_gcs_connected", return_value=False), \
             patch("api.events.is_refreshing", return_value=False):
            resp = client.get("/api/events/health")

        data = resp.get_json()
        assert resp.status_code == 200
        assert data["gcs"] == "disconnected"

    def test_event_count_zero_when_gcs_disconnected(self, client):
        with patch("services.gcs_client.is_gcs_connected", return_value=False), \
             patch("repositories.event_repository.event_repository") as repo, \
             patch("api.events.is_refreshing", return_value=False):
            resp = client.get("/api/events/health")

        repo.count.assert_not_called()
        data = resp.get_json()
        assert data["event_count"] == 0

    def test_refreshing_status_reflected_in_health(self, client):
        with patch("services.gcs_client.is_gcs_connected", return_value=True), \
             patch("repositories.event_repository.event_repository") as repo, \
             patch("api.events.is_refreshing", return_value=True):
            repo.count.return_value = 0

            resp = client.get("/api/events/health")

        assert resp.get_json()["refreshing"] is True

    def test_exception_returns_degraded_200(self, client):
        with patch("services.gcs_client.is_gcs_connected", side_effect=Exception("crash")):
            resp = client.get("/api/events/health")

        data = resp.get_json()
        assert resp.status_code == 200
        assert data["status"] == "degraded"
        assert "error" in data

    def test_health_response_contains_all_fields(self, client):
        with patch("services.gcs_client.is_gcs_connected", return_value=True), \
             patch("repositories.event_repository.event_repository") as repo, \
             patch("api.events.is_refreshing", return_value=False):
            repo.count.return_value = 0

            resp = client.get("/api/events/health")

        data = resp.get_json()
        for field in ["status", "service", "storage", "gcs", "event_count", "refreshing"]:
            assert field in data, f"Field '{field}' missing from health response"
