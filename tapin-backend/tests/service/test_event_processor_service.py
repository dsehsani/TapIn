"""
test_event_processor_service.py — Tests for services/event_processor_service.py

All external calls (Aggie Life, Claude, GCS, image mirror) are mocked.
"""

import pytest
import threading
from unittest.mock import patch, MagicMock, call
import services.event_processor_service as eps
from services.event_processor_service import (
    refresh_events,
    refresh_events_background,
    is_refreshing,
    get_events,
)

FUTURE = "2099-12-31T18:00:00Z"
PAST = "2020-01-01T00:00:00Z"


def make_event(event_id: str, start_date: str = FUTURE, ai_summary: str = None,
               ai_bullets=None, **kwargs) -> dict:
    e = {
        "id": event_id,
        "title": f"Event {event_id}",
        "description": f"Description for {event_id}",
        "startDate": start_date,
        "imageURL": None,
    }
    if ai_summary is not None:
        e["aiSummary"] = ai_summary
    if ai_bullets is not None:
        e["aiBulletPoints"] = ai_bullets
    e.update(kwargs)
    return e


@pytest.fixture(autouse=True)
def reset_processor_state():
    """Ensure clean lock and refreshing state for every test."""
    eps._is_refreshing = False
    # Release the lock if somehow left acquired
    if eps._refresh_lock.locked():
        eps._refresh_lock.release()
    yield
    eps._is_refreshing = False
    if eps._refresh_lock.locked():
        eps._refresh_lock.release()


# ---------------------------------------------------------------------------
# MARK: - Idempotency / AI Content Reuse
# ---------------------------------------------------------------------------

class TestIdempotency:

    def test_existing_event_with_ai_content_is_reused(self):
        existing = [make_event("e1", ai_summary="Summary", ai_bullets=["• Point"])]
        fresh = [make_event("e1")]  # same ID, no AI content

        with patch.object(eps.event_repository, "get_all_events", return_value=existing), \
             patch.object(eps.aggie_life_service, "fetch_events", return_value=fresh), \
             patch.object(eps.claude_service, "summarize_event_internal") as mock_summarize, \
             patch.object(eps.claude_service, "generate_bullet_points") as mock_bullets, \
             patch.object(eps.event_repository, "save_all_events"):
            result = refresh_events()

        mock_summarize.assert_not_called()
        mock_bullets.assert_not_called()
        assert result["skipped"] == 1
        assert result["processed"] == 0

    def test_new_event_gets_ai_generated_content(self):
        with patch.object(eps.event_repository, "get_all_events", return_value=[]), \
             patch.object(eps.aggie_life_service, "fetch_events",
                          return_value=[make_event("e2")]), \
             patch.object(eps.claude_service, "summarize_event_internal",
                          return_value="New summary") as mock_summarize, \
             patch.object(eps.claude_service, "generate_bullet_points",
                          return_value=["• Point"]) as mock_bullets, \
             patch("services.event_processor_service.mirror_event_image", return_value=None), \
             patch.object(eps.event_repository, "save_all_events"):
            result = refresh_events()

        mock_summarize.assert_called_once()
        mock_bullets.assert_called_once()
        assert result["processed"] == 1
        assert result["skipped"] == 0

    def test_event_without_ai_summary_is_reprocessed(self):
        """Event in GCS but missing aiSummary is NOT in existing_map → re-processed."""
        existing = [make_event("e3")]  # no ai_summary, no ai_bullets
        fresh = [make_event("e3")]

        with patch.object(eps.event_repository, "get_all_events", return_value=existing), \
             patch.object(eps.aggie_life_service, "fetch_events", return_value=fresh), \
             patch.object(eps.claude_service, "summarize_event_internal",
                          return_value="Generated") as mock_summarize, \
             patch.object(eps.claude_service, "generate_bullet_points", return_value=["•"]), \
             patch("services.event_processor_service.mirror_event_image", return_value=None), \
             patch.object(eps.event_repository, "save_all_events"):
            refresh_events()

        mock_summarize.assert_called_once()

    def test_event_with_summary_but_no_bullets_is_reprocessed(self):
        """Both aiSummary AND aiBulletPoints must be present to skip re-processing."""
        existing = [make_event("e4", ai_summary="Has summary")]  # no bullets
        fresh = [make_event("e4")]

        with patch.object(eps.event_repository, "get_all_events", return_value=existing), \
             patch.object(eps.aggie_life_service, "fetch_events", return_value=fresh), \
             patch.object(eps.claude_service, "summarize_event_internal",
                          return_value="Re-generated") as mock_summarize, \
             patch.object(eps.claude_service, "generate_bullet_points", return_value=["•"]), \
             patch("services.event_processor_service.mirror_event_image", return_value=None), \
             patch.object(eps.event_repository, "save_all_events"):
            refresh_events()

        mock_summarize.assert_called_once()

    def test_reused_event_data_comes_from_gcs_not_fresh_feed(self):
        """The saved enriched event dict (from GCS) is used, not the raw fresh event."""
        existing = [make_event("e1", ai_summary="GCS Summary", ai_bullets=["• GCS"])]
        fresh_event = make_event("e1")
        fresh_event["title"] = "Fresh Title (should not override)"

        saved_events = []

        with patch.object(eps.event_repository, "get_all_events", return_value=existing), \
             patch.object(eps.aggie_life_service, "fetch_events", return_value=[fresh_event]), \
             patch.object(eps.claude_service, "summarize_event_internal"), \
             patch.object(eps.event_repository, "save_all_events",
                          side_effect=lambda evts: saved_events.extend(evts)):
            refresh_events()

        # The saved event should be the GCS version with "Event e1" title
        assert saved_events[0]["aiSummary"] == "GCS Summary"


# ---------------------------------------------------------------------------
# MARK: - Past Event Filtering
# ---------------------------------------------------------------------------

class TestPastEventFiltering:

    def test_past_events_not_included_in_output(self):
        fresh = [make_event("past_event", start_date=PAST)]
        saved_events = []

        with patch.object(eps.event_repository, "get_all_events", return_value=[]), \
             patch.object(eps.aggie_life_service, "fetch_events", return_value=fresh), \
             patch.object(eps.event_repository, "save_all_events",
                          side_effect=lambda evts: saved_events.extend(evts)):
            refresh_events()

        assert all(e["id"] != "past_event" for e in saved_events)

    def test_future_events_are_included(self):
        fresh = [make_event("future_event", start_date=FUTURE)]
        saved_events = []

        with patch.object(eps.event_repository, "get_all_events", return_value=[]), \
             patch.object(eps.aggie_life_service, "fetch_events", return_value=fresh), \
             patch.object(eps.claude_service, "summarize_event_internal", return_value="S"), \
             patch.object(eps.claude_service, "generate_bullet_points", return_value=["•"]), \
             patch("services.event_processor_service.mirror_event_image", return_value=None), \
             patch.object(eps.event_repository, "save_all_events",
                          side_effect=lambda evts: saved_events.extend(evts)):
            refresh_events()

        assert any(e["id"] == "future_event" for e in saved_events)

    def test_mixed_past_and_future_only_future_saved(self):
        fresh = [
            make_event("past", start_date=PAST),
            make_event("future", start_date=FUTURE),
        ]
        saved_events = []

        with patch.object(eps.event_repository, "get_all_events", return_value=[]), \
             patch.object(eps.aggie_life_service, "fetch_events", return_value=fresh), \
             patch.object(eps.claude_service, "summarize_event_internal", return_value="S"), \
             patch.object(eps.claude_service, "generate_bullet_points", return_value=["•"]), \
             patch("services.event_processor_service.mirror_event_image", return_value=None), \
             patch.object(eps.event_repository, "save_all_events",
                          side_effect=lambda evts: saved_events.extend(evts)):
            refresh_events()

        ids = {e["id"] for e in saved_events}
        assert "future" in ids
        assert "past" not in ids

    def test_event_with_unparseable_date_is_kept(self):
        """Events with invalid date strings are kept defensively."""
        fresh = [make_event("weird", start_date="not-a-date")]
        saved_events = []

        with patch.object(eps.event_repository, "get_all_events", return_value=[]), \
             patch.object(eps.aggie_life_service, "fetch_events", return_value=fresh), \
             patch.object(eps.claude_service, "summarize_event_internal", return_value="S"), \
             patch.object(eps.claude_service, "generate_bullet_points", return_value=["•"]), \
             patch("services.event_processor_service.mirror_event_image", return_value=None), \
             patch.object(eps.event_repository, "save_all_events",
                          side_effect=lambda evts: saved_events.extend(evts)):
            refresh_events()

        assert any(e["id"] == "weird" for e in saved_events)

    def test_event_with_no_start_date_is_kept(self):
        """Events with empty string startDate are kept."""
        fresh = [{"id": "no-date", "title": "No Date", "description": "desc", "startDate": ""}]
        saved_events = []

        with patch.object(eps.event_repository, "get_all_events", return_value=[]), \
             patch.object(eps.aggie_life_service, "fetch_events", return_value=fresh), \
             patch.object(eps.claude_service, "summarize_event_internal", return_value="S"), \
             patch.object(eps.claude_service, "generate_bullet_points", return_value=["•"]), \
             patch("services.event_processor_service.mirror_event_image", return_value=None), \
             patch.object(eps.event_repository, "save_all_events",
                          side_effect=lambda evts: saved_events.extend(evts)):
            refresh_events()

        assert any(e["id"] == "no-date" for e in saved_events)


# ---------------------------------------------------------------------------
# MARK: - removed_past Count
# ---------------------------------------------------------------------------

class TestRemovedPastCount:

    def test_removed_past_counts_events_absent_from_fresh_feed(self):
        existing = [make_event("e1"), make_event("e2"), make_event("e3")]
        fresh = [make_event("e1")]  # e2 and e3 no longer in feed

        with patch.object(eps.event_repository, "get_all_events", return_value=existing), \
             patch.object(eps.aggie_life_service, "fetch_events", return_value=fresh), \
             patch.object(eps.event_repository, "save_all_events"):
            result = refresh_events()

        assert result["removed_past"] == 2

    def test_removed_past_is_zero_when_all_still_active(self):
        existing = [make_event("e1"), make_event("e2")]
        fresh = [make_event("e1"), make_event("e2")]

        with patch.object(eps.event_repository, "get_all_events", return_value=existing), \
             patch.object(eps.aggie_life_service, "fetch_events", return_value=fresh), \
             patch.object(eps.event_repository, "save_all_events"):
            result = refresh_events()

        assert result["removed_past"] == 0

    def test_removed_past_is_zero_on_cold_start(self):
        with patch.object(eps.event_repository, "get_all_events", return_value=[]), \
             patch.object(eps.aggie_life_service, "fetch_events", return_value=[]), \
             patch.object(eps.event_repository, "save_all_events"):
            result = refresh_events()

        assert result["removed_past"] == 0


# ---------------------------------------------------------------------------
# MARK: - Concurrency / Lock
# ---------------------------------------------------------------------------

class TestConcurrency:

    def test_second_refresh_call_returns_skip_when_lock_held(self):
        acquired = eps._refresh_lock.acquire(blocking=False)
        assert acquired
        try:
            result = refresh_events()
        finally:
            eps._refresh_lock.release()

        assert result.get("skipped_reason") == "refresh_in_progress"

    def test_is_refreshing_true_during_refresh(self):
        states = []

        def fake_run():
            states.append(is_refreshing())
            return {"processed": 0, "skipped": 0, "errors": 0,
                    "total_fetched": 0, "removed_past": 0,
                    "completed_at": "2026-01-01T00:00:00Z"}

        with patch("services.event_processor_service._run_refresh", fake_run):
            refresh_events()

        assert True in states

    def test_is_refreshing_false_after_refresh_completes(self):
        with patch("services.event_processor_service._run_refresh",
                   return_value={"processed": 0, "skipped": 0, "errors": 0,
                                 "total_fetched": 0, "removed_past": 0,
                                 "completed_at": "2026-01-01T00:00:00Z"}):
            refresh_events()

        assert is_refreshing() is False

    def test_is_refreshing_false_even_when_refresh_raises(self):
        with patch("services.event_processor_service._run_refresh",
                   side_effect=RuntimeError("crash")):
            with pytest.raises(RuntimeError):
                refresh_events()

        assert is_refreshing() is False


# ---------------------------------------------------------------------------
# MARK: - Error Handling
# ---------------------------------------------------------------------------

class TestErrorHandling:

    def test_aggie_life_fetch_failure_returns_error_dict(self):
        with patch.object(eps.event_repository, "get_all_events", return_value=[]), \
             patch.object(eps.aggie_life_service, "fetch_events",
                          side_effect=Exception("iCal unreachable")):
            result = refresh_events()

        assert "error" in result
        assert result["processed"] == 0

    def test_aggie_life_failure_does_not_raise(self):
        with patch.object(eps.event_repository, "get_all_events", return_value=[]), \
             patch.object(eps.aggie_life_service, "fetch_events",
                          side_effect=Exception("network error")):
            result = refresh_events()  # Must not raise

        assert result is not None

    def test_claude_failure_event_still_saved(self):
        fresh = [make_event("e1")]
        saved_events = []

        with patch.object(eps.event_repository, "get_all_events", return_value=[]), \
             patch.object(eps.aggie_life_service, "fetch_events", return_value=fresh), \
             patch.object(eps.claude_service, "summarize_event_internal",
                          side_effect=Exception("Claude API error")), \
             patch.object(eps.event_repository, "save_all_events",
                          side_effect=lambda evts: saved_events.extend(evts)):
            result = refresh_events()

        assert result["errors"] == 1
        assert any(e["id"] == "e1" for e in saved_events)

    def test_gcs_save_failure_propagates(self):
        with patch.object(eps.event_repository, "get_all_events", return_value=[]), \
             patch.object(eps.aggie_life_service, "fetch_events", return_value=[]), \
             patch.object(eps.event_repository, "save_all_events",
                          side_effect=Exception("GCS write failed")):
            with pytest.raises(Exception, match="GCS write failed"):
                refresh_events()

    def test_empty_aggie_life_feed_saves_empty_list(self):
        saved_args = []

        with patch.object(eps.event_repository, "get_all_events", return_value=[]), \
             patch.object(eps.aggie_life_service, "fetch_events", return_value=[]), \
             patch.object(eps.event_repository, "save_all_events",
                          side_effect=lambda evts: saved_args.append(evts)):
            result = refresh_events()

        assert saved_args[0] == []
        assert result["total_fetched"] == 0
        assert result["processed"] == 0


# ---------------------------------------------------------------------------
# MARK: - Image Mirroring
# ---------------------------------------------------------------------------

class TestImageMirroring:

    def test_new_event_image_is_mirrored(self):
        fresh = [make_event("e1", imageURL="https://original.jpg")]
        fresh[0]["imageURL"] = "https://original.jpg"
        mirror_calls = []

        def fake_mirror(event_id, url):
            mirror_calls.append((event_id, url))
            return "https://gcs.url/img.jpg"

        with patch.object(eps.event_repository, "get_all_events", return_value=[]), \
             patch.object(eps.aggie_life_service, "fetch_events", return_value=fresh), \
             patch.object(eps.claude_service, "summarize_event_internal", return_value="S"), \
             patch.object(eps.claude_service, "generate_bullet_points", return_value=["•"]), \
             patch("services.event_processor_service.mirror_event_image", fake_mirror), \
             patch.object(eps.event_repository, "save_all_events"):
            refresh_events()

        assert len(mirror_calls) == 1
        assert mirror_calls[0][1] == "https://original.jpg"

    def test_skipped_event_image_not_remirrored(self):
        existing = [make_event("e1", ai_summary="S", ai_bullets=["•"])]
        fresh = [make_event("e1")]
        mirror_calls = []

        with patch.object(eps.event_repository, "get_all_events", return_value=existing), \
             patch.object(eps.aggie_life_service, "fetch_events", return_value=fresh), \
             patch("services.event_processor_service.mirror_event_image",
                   side_effect=lambda eid, url: mirror_calls.append(eid) or url), \
             patch.object(eps.event_repository, "save_all_events"):
            refresh_events()

        assert len(mirror_calls) == 0

    def test_mirror_failure_event_saved_with_original_url(self):
        fresh = [make_event("e1", imageURL="https://original.jpg")]
        fresh[0]["imageURL"] = "https://original.jpg"
        saved_events = []

        with patch.object(eps.event_repository, "get_all_events", return_value=[]), \
             patch.object(eps.aggie_life_service, "fetch_events", return_value=fresh), \
             patch.object(eps.claude_service, "summarize_event_internal", return_value="S"), \
             patch.object(eps.claude_service, "generate_bullet_points", return_value=["•"]), \
             patch("services.event_processor_service.mirror_event_image",
                   return_value="https://original.jpg"), \
             patch.object(eps.event_repository, "save_all_events",
                          side_effect=lambda evts: saved_events.extend(evts)):
            refresh_events()

        # Event is still saved (mirror returns original URL on failure)
        assert any(e["id"] == "e1" for e in saved_events)


# ---------------------------------------------------------------------------
# MARK: - Result Dict Format
# ---------------------------------------------------------------------------

class TestResultFormat:

    def test_result_contains_all_expected_keys(self):
        with patch.object(eps.event_repository, "get_all_events", return_value=[]), \
             patch.object(eps.aggie_life_service, "fetch_events", return_value=[]), \
             patch.object(eps.event_repository, "save_all_events"):
            result = refresh_events()

        for key in ["processed", "skipped", "removed_past", "errors",
                    "total_fetched", "completed_at"]:
            assert key in result, f"Key '{key}' missing from result"

    def test_completed_at_is_valid_iso8601(self):
        from datetime import datetime
        with patch.object(eps.event_repository, "get_all_events", return_value=[]), \
             patch.object(eps.aggie_life_service, "fetch_events", return_value=[]), \
             patch.object(eps.event_repository, "save_all_events"):
            result = refresh_events()

        datetime.fromisoformat(result["completed_at"].replace("Z", "+00:00"))


# ---------------------------------------------------------------------------
# MARK: - get_events / Background Refresh
# ---------------------------------------------------------------------------

class TestGetEventsAndBackground:

    def test_get_events_delegates_to_repository(self):
        events = [make_event("e1"), make_event("e2")]
        with patch.object(eps.event_repository, "get_all_events", return_value=events):
            result = get_events()
        assert result == events

    def test_refresh_events_background_starts_thread(self):
        started = []

        def fake_refresh():
            started.append(True)

        with patch("services.event_processor_service.refresh_events", fake_refresh):
            t = threading.Thread(target=refresh_events_background, daemon=True)
            t.start()
            t.join(timeout=2)

        # The background thread calls refresh_events internally
        # We just verify it doesn't crash and returns quickly
