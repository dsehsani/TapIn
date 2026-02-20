"""
test_article_content_repository.py — Unit tests for
repositories/article_content_repository.py
"""

import pytest
from unittest.mock import patch
from repositories.article_content_repository import ArticleContentRepository

SAMPLE_CONTENT = {
    "title": "Full Article",
    "author": "John Doe",
    "authorEmail": "jdoe@ucdavis.edu",
    "publishDate": "2026-02-18T09:00:00Z",
    "category": "sports",
    "thumbnailURL": "https://theaggie.org/thumb.jpg",
    "bodyParagraphs": ["First paragraph.", "Second paragraph."],
    "articleURL": "https://theaggie.org/article",
}


@pytest.fixture
def repo():
    return ArticleContentRepository()


# ---------------------------------------------------------------------------
# MARK: - save_article_content / get_article_content
# ---------------------------------------------------------------------------

class TestSaveAndGetArticleContent:

    def test_round_trip(self, repo):
        stored = {}

        def fake_write(path, data, cache_control="public, max-age=1800"):
            stored["path"] = path
            stored["data"] = dict(data)

        def fake_read(path):
            if path == stored.get("path"):
                return stored["data"]
            return None

        with patch("repositories.article_content_repository.write_json", fake_write), \
             patch("repositories.article_content_repository.read_json", fake_read):
            repo.save_article_content("abc123", dict(SAMPLE_CONTENT))
            result = repo.get_article_content("abc123")

        assert result is not None
        assert result["title"] == "Full Article"
        assert result["author"] == "John Doe"
        assert result["bodyParagraphs"] == ["First paragraph.", "Second paragraph."]

    def test_get_returns_none_when_not_cached(self, repo):
        with patch("repositories.article_content_repository.read_json", return_value=None):
            assert repo.get_article_content("unknown-id") is None

    def test_get_returns_none_on_read_error(self, repo):
        with patch("repositories.article_content_repository.read_json", side_effect=Exception("GCS error")):
            assert repo.get_article_content("abc123") is None

    def test_save_injects_scraped_at_timestamp(self, repo):
        written = {}

        def fake_write(path, data, **kw):
            written.update(data)

        with patch("repositories.article_content_repository.write_json", fake_write):
            repo.save_article_content("abc123", dict(SAMPLE_CONTENT))

        assert "scrapedAt" in written
        # Should be ISO 8601 format
        from datetime import datetime
        parsed = datetime.fromisoformat(written["scrapedAt"].replace("Z", "+00:00"))
        assert parsed is not None

    def test_save_uses_correct_gcs_path(self, repo):
        paths = []

        def fake_write(path, data, **kw):
            paths.append(path)

        with patch("repositories.article_content_repository.write_json", fake_write):
            repo.save_article_content("my-article-id-123", dict(SAMPLE_CONTENT))

        assert paths == ["article-content/my-article-id-123.json"]

    def test_get_uses_correct_gcs_path(self, repo):
        paths = []

        def fake_read(path):
            paths.append(path)
            return None

        with patch("repositories.article_content_repository.read_json", fake_read):
            repo.get_article_content("some-sha256-id")

        assert paths == ["article-content/some-sha256-id.json"]

    def test_save_uses_long_cache_control_for_immutable_content(self, repo):
        cache_controls = []

        def fake_write(path, data, cache_control="public, max-age=1800"):
            cache_controls.append(cache_control)

        with patch("repositories.article_content_repository.write_json", fake_write):
            repo.save_article_content("abc", dict(SAMPLE_CONTENT))

        assert cache_controls == ["public, max-age=86400"]

    def test_save_raises_on_write_failure(self, repo):
        with patch("repositories.article_content_repository.write_json", side_effect=Exception("disk full")):
            with pytest.raises(Exception, match="disk full"):
                repo.save_article_content("abc123", dict(SAMPLE_CONTENT))

    def test_scraped_at_does_not_overwrite_existing_value(self, repo):
        """scrapedAt should always be set to now, not from caller."""
        content_with_old_ts = dict(SAMPLE_CONTENT)
        content_with_old_ts["scrapedAt"] = "2000-01-01T00:00:00Z"
        written = {}

        def fake_write(path, data, **kw):
            written.update(data)

        with patch("repositories.article_content_repository.write_json", fake_write):
            repo.save_article_content("abc", content_with_old_ts)

        # The service always overwrites scrapedAt with current time
        assert written["scrapedAt"] != "2000-01-01T00:00:00Z"

    def test_save_preserves_all_content_fields(self, repo):
        written = {}

        def fake_write(path, data, **kw):
            written.update(data)

        with patch("repositories.article_content_repository.write_json", fake_write):
            repo.save_article_content("abc", dict(SAMPLE_CONTENT))

        for key in SAMPLE_CONTENT:
            assert key in written, f"Field '{key}' missing from saved content"
