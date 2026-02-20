"""
test_event_repository.py — Unit tests for repositories/event_repository.py

Patches gcs_client functions at the import site so no real GCS calls are made.
"""

import json
import pytest
from unittest.mock import patch
from repositories.event_repository import EventRepository

FUTURE = "2099-12-31T18:00:00Z"
NEAR_FUTURE = "2099-06-15T09:00:00Z"
EVEN_LATER = "2099-12-31T23:59:00Z"


def make_event(event_id: str, start_date: str = FUTURE, **kwargs) -> dict:
    return {
        "id": event_id,
        "title": f"Event {event_id}",
        "startDate": start_date,
        "aiSummary": "A summary.",
        "aiBulletPoints": ["• Point"],
        **kwargs,
    }


@pytest.fixture
def repo():
    return EventRepository()


# ---------------------------------------------------------------------------
# MARK: - save_all_events / get_all_events
# ---------------------------------------------------------------------------

class TestSaveAndGetAllEvents:

    def test_round_trip(self, repo):
        events = [make_event("e1"), make_event("e2")]
        saved = {}

        def fake_write(path, data, cache_control="public, max-age=1800"):
            saved["data"] = data

        def fake_read(path):
            return saved.get("data")

        with patch("repositories.event_repository.write_json", fake_write), \
             patch("repositories.event_repository.read_json", fake_read):
            repo.save_all_events(events)
            result = repo.get_all_events()

        assert len(result) == 2
        ids = {e["id"] for e in result}
        assert ids == {"e1", "e2"}

    def test_get_returns_empty_list_on_cold_start(self, repo):
        with patch("repositories.event_repository.read_json", return_value=None):
            assert repo.get_all_events() == []

    def test_get_returns_empty_list_when_events_key_missing(self, repo):
        with patch("repositories.event_repository.read_json", return_value={"count": 0}):
            assert repo.get_all_events() == []

    def test_get_returns_empty_list_on_read_error(self, repo):
        with patch("repositories.event_repository.read_json", side_effect=Exception("GCS down")):
            assert repo.get_all_events() == []

    def test_events_sorted_by_start_date_ascending(self, repo):
        events = [
            make_event("e1", start_date="2099-03-10T10:00:00Z"),
            make_event("e2", start_date="2099-03-05T08:00:00Z"),
            make_event("e3", start_date="2099-03-08T15:00:00Z"),
        ]
        stored = {}

        def fake_write(path, data, **kw):
            stored["data"] = data

        def fake_read(path):
            return stored.get("data")

        with patch("repositories.event_repository.write_json", fake_write), \
             patch("repositories.event_repository.read_json", fake_read):
            repo.save_all_events(events)
            result = repo.get_all_events()

        assert result[0]["id"] == "e2"  # earliest
        assert result[1]["id"] == "e3"
        assert result[2]["id"] == "e1"  # latest

    def test_sort_is_chronological_not_lexicographic(self, repo):
        # Lexicographic sort would put "2099-02..." before "2099-10..."
        # but "2099-10-01" > "2099-02-01" chronologically
        events = [
            make_event("oct", start_date="2099-10-01T00:00:00Z"),
            make_event("feb", start_date="2099-02-01T00:00:00Z"),
            make_event("jun", start_date="2099-06-15T00:00:00Z"),
        ]
        stored = {}

        def fake_write(path, data, **kw):
            stored["data"] = data

        def fake_read(path):
            return stored.get("data")

        with patch("repositories.event_repository.write_json", fake_write), \
             patch("repositories.event_repository.read_json", fake_read):
            repo.save_all_events(events)
            result = repo.get_all_events()

        assert result[0]["id"] == "feb"
        assert result[1]["id"] == "jun"
        assert result[2]["id"] == "oct"

    def test_save_writes_correct_metadata(self, repo):
        events = [make_event("e1"), make_event("e2")]
        written = {}

        def fake_write(path, data, **kw):
            written.update(data)

        with patch("repositories.event_repository.write_json", fake_write), \
             patch("repositories.event_repository.read_json", return_value=None):
            repo.save_all_events(events)

        assert written["count"] == 2
        assert "refreshed_at" in written
        assert written["events"] == events

    def test_save_to_correct_gcs_path(self, repo):
        paths_written = []

        def fake_write(path, data, **kw):
            paths_written.append(path)

        with patch("repositories.event_repository.write_json", fake_write):
            repo.save_all_events([])

        assert paths_written == ["events/current.json"]

    def test_save_empty_list_does_not_raise(self, repo):
        with patch("repositories.event_repository.write_json") as mock_write:
            repo.save_all_events([])
            data = mock_write.call_args[0][1]
            assert data["count"] == 0
            assert data["events"] == []

    def test_save_overwrites_previous_data(self, repo):
        store = {}

        def fake_write(path, data, **kw):
            store[path] = data

        def fake_read(path):
            return store.get(path)

        with patch("repositories.event_repository.write_json", fake_write), \
             patch("repositories.event_repository.read_json", fake_read):
            repo.save_all_events([make_event("old1"), make_event("old2"), make_event("old3")])
            repo.save_all_events([make_event("new1")])
            result = repo.get_all_events()

        assert len(result) == 1
        assert result[0]["id"] == "new1"

    def test_save_raises_on_write_error(self, repo):
        with patch("repositories.event_repository.write_json", side_effect=Exception("write failed")):
            with pytest.raises(Exception, match="write failed"):
                repo.save_all_events([make_event("e1")])

    def test_events_with_missing_start_date_sort_to_front(self, repo):
        events = [
            make_event("has_date", start_date="2099-06-01T00:00:00Z"),
            {"id": "no_date", "title": "No Date"},
        ]
        stored = {}

        def fake_write(path, data, **kw):
            stored["data"] = data

        def fake_read(path):
            return stored.get("data")

        with patch("repositories.event_repository.write_json", fake_write), \
             patch("repositories.event_repository.read_json", fake_read):
            repo.save_all_events(events)
            result = repo.get_all_events()

        # Missing startDate defaults to "" which sorts before any date
        assert result[0]["id"] == "no_date"
        assert result[1]["id"] == "has_date"


# ---------------------------------------------------------------------------
# MARK: - count
# ---------------------------------------------------------------------------

class TestCount:

    def test_returns_count_from_file(self, repo):
        with patch("repositories.event_repository.read_json", return_value={"count": 12, "events": []}):
            assert repo.count() == 12

    def test_returns_zero_when_no_file(self, repo):
        with patch("repositories.event_repository.read_json", return_value=None):
            assert repo.count() == 0

    def test_returns_zero_when_count_key_absent(self, repo):
        with patch("repositories.event_repository.read_json", return_value={"events": []}):
            assert repo.count() == 0

    def test_returns_zero_on_read_error(self, repo):
        with patch("repositories.event_repository.read_json", side_effect=Exception("fail")):
            assert repo.count() == 0
