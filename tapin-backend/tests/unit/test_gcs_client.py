"""
test_gcs_client.py — Unit tests for services/gcs_client.py

Uses the mock_bucket fixture from conftest.py which replaces the real GCS
bucket singleton with an in-memory store.
"""

import json
import pytest
from datetime import datetime, timezone, timedelta
from unittest.mock import MagicMock, patch

from services.gcs_client import (
    write_json,
    read_json,
    file_age_seconds,
    upload_image,
    is_gcs_connected,
)


# ---------------------------------------------------------------------------
# MARK: - write_json / read_json
# ---------------------------------------------------------------------------

class TestWriteReadJson:

    def test_round_trip_returns_same_data(self, mock_bucket):
        _, store = mock_bucket
        data = {"key": "value", "count": 42, "nested": {"a": 1}}
        write_json("articles/all.json", data)
        result = read_json("articles/all.json")
        assert result == data

    def test_read_nonexistent_path_returns_none(self, mock_bucket):
        result = read_json("does/not/exist.json")
        assert result is None

    def test_write_sets_cache_control_header(self, mock_bucket):
        _, store = mock_bucket

        # Capture the blob to inspect its cache_control after patch()
        blobs_created = []
        original_blob = mock_bucket[0].blob

        def tracking_blob(path):
            b = original_blob(path)
            blobs_created.append(b)
            return b

        mock_bucket[0].blob = tracking_blob
        write_json("test.json", {"x": 1}, cache_control="public, max-age=300")
        assert any(b.cache_control == "public, max-age=300" for b in blobs_created)

    def test_write_default_cache_control_is_30_minutes(self, mock_bucket):
        blobs_created = []
        original_blob = mock_bucket[0].blob

        def tracking_blob(path):
            b = original_blob(path)
            blobs_created.append(b)
            return b

        mock_bucket[0].blob = tracking_blob
        write_json("test.json", {"x": 1})
        assert any(b.cache_control == "public, max-age=1800" for b in blobs_created)

    def test_write_handles_datetime_via_default_str(self, mock_bucket):
        data = {"ts": datetime(2026, 2, 19, 12, 0, 0, tzinfo=timezone.utc)}
        # Should not raise TypeError
        write_json("test.json", data)
        raw = read_json("test.json")
        assert raw is not None
        assert isinstance(raw["ts"], str)  # datetime was stringified

    def test_stored_value_is_valid_json(self, mock_bucket):
        _, store = mock_bucket
        data = {"articles": [{"id": "1", "title": "A"}]}
        write_json("articles/campus.json", data)
        raw_str = store["articles/campus.json"]["data"]
        parsed = json.loads(raw_str)
        assert parsed == data

    def test_write_overwrites_previous_value(self, mock_bucket):
        write_json("test.json", {"v": 1})
        write_json("test.json", {"v": 2})
        result = read_json("test.json")
        assert result == {"v": 2}

    def test_read_returns_none_on_download_error(self, mock_bucket, monkeypatch):
        _, store = mock_bucket
        # Pre-populate store so blob.exists() returns True
        store["broken.json"] = {
            "data": "not-json",
            "content_type": "application/json",
            "updated": datetime.now(tz=timezone.utc),
        }
        # Force json.loads to fail by storing invalid JSON
        store["broken.json"]["data"] = "{invalid json{{{"
        result = read_json("broken.json")
        assert result is None

    def test_read_empty_dict_is_valid(self, mock_bucket):
        write_json("empty.json", {})
        assert read_json("empty.json") == {}

    def test_write_large_payload(self, mock_bucket):
        data = {"articles": [{"id": str(i), "title": f"Article {i}"} for i in range(500)]}
        write_json("articles/all.json", data)
        result = read_json("articles/all.json")
        assert len(result["articles"]) == 500


# ---------------------------------------------------------------------------
# MARK: - file_age_seconds
# ---------------------------------------------------------------------------

class TestFileAgeSeconds:

    def test_missing_file_returns_none(self, mock_bucket):
        result = file_age_seconds("no/such/file.json")
        assert result is None

    def test_fresh_file_returns_small_positive_float(self, mock_bucket):
        write_json("fresh.json", {"x": 1})
        age = file_age_seconds("fresh.json")
        assert age is not None
        assert 0 <= age < 5  # Should be essentially instant

    def test_age_increases_with_time(self, mock_bucket, monkeypatch):
        _, store = mock_bucket
        # Pre-set the updated timestamp to 60 seconds ago
        past = datetime.now(tz=timezone.utc) - timedelta(seconds=60)
        store["old.json"] = {
            "data": '{"x": 1}',
            "content_type": "application/json",
            "updated": past,
        }
        age = file_age_seconds("old.json")
        assert age is not None
        assert age >= 59  # At least 59 seconds (allow tiny float drift)

    def test_returns_none_on_reload_error(self, mock_bucket, monkeypatch):
        _, store = mock_bucket
        store["test.json"] = {
            "data": "{}",
            "content_type": "application/json",
            "updated": datetime.now(tz=timezone.utc),
        }

        # Make the blob's reload raise
        original_blob = mock_bucket[0].blob

        class ErrorBlob:
            def __init__(self, path):
                self._inner = original_blob(path)
                self.updated = self._inner.updated

            def exists(self):
                return self._inner.exists()

            def reload(self):
                raise ConnectionError("GCS unreachable")

        mock_bucket[0].blob = lambda path: ErrorBlob(path)
        result = file_age_seconds("test.json")
        assert result is None

    def test_returns_none_when_updated_is_none(self, mock_bucket, monkeypatch):
        _, store = mock_bucket
        store["test.json"] = {
            "data": "{}",
            "content_type": "application/json",
            "updated": None,
        }
        # blob.reload() sets self.updated from store; if store["updated"] is None
        # the code should guard against None
        result = file_age_seconds("test.json")
        # Either None (if gcs_client handles None updated) or a valid float
        # The implementation checks `if blob.updated is None: return None`
        assert result is None


# ---------------------------------------------------------------------------
# MARK: - upload_image
# ---------------------------------------------------------------------------

class TestUploadImage:

    def test_returns_public_url_string(self, mock_bucket):
        url = upload_image("images/articles/abc.jpg", b"\xff\xd8\xff", "image/jpeg")
        assert isinstance(url, str)
        assert len(url) > 0

    def test_public_url_contains_path(self, mock_bucket):
        url = upload_image("images/events/xyz.jpg", b"data", "image/jpeg")
        assert "images/events/xyz.jpg" in url

    def test_png_content_type_accepted(self, mock_bucket):
        url = upload_image("images/articles/abc.png", b"png-data", "image/png")
        assert url is not None

    def test_make_public_is_called(self, mock_bucket):
        called = []
        original_blob = mock_bucket[0].blob

        class TrackingBlob:
            def __init__(self, path):
                self._inner = original_blob(path)
                self.public_url = self._inner.public_url
                self.cache_control = None

            def upload_from_string(self, data, content_type="image/jpeg"):
                self._inner.upload_from_string(data, content_type)

            def make_public(self):
                called.append(True)

            def patch(self):
                pass

        mock_bucket[0].blob = lambda path: TrackingBlob(path)
        upload_image("images/test.jpg", b"data")
        assert len(called) == 1


# ---------------------------------------------------------------------------
# MARK: - is_gcs_connected
# ---------------------------------------------------------------------------

class TestIsGcsConnected:

    def test_returns_true_when_bucket_accessible(self, mock_bucket):
        assert is_gcs_connected() is True

    def test_returns_false_when_bucket_reload_raises(self, monkeypatch):
        failing_bucket = MagicMock()
        failing_bucket.reload.side_effect = Exception("connection refused")
        monkeypatch.setattr("services.gcs_client._bucket", failing_bucket)
        monkeypatch.setattr("services.gcs_client._gcs_client", MagicMock())
        assert is_gcs_connected() is False

    def test_returns_false_does_not_raise(self, monkeypatch):
        failing_bucket = MagicMock()
        failing_bucket.reload.side_effect = RuntimeError("network error")
        monkeypatch.setattr("services.gcs_client._bucket", failing_bucket)
        monkeypatch.setattr("services.gcs_client._gcs_client", MagicMock())
        # Must not propagate the exception
        result = is_gcs_connected()
        assert result is False
