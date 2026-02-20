"""
test_article_repository.py — Unit tests for repositories/article_repository.py

Patches gcs_client functions at the import site so no real GCS calls are made.
"""

import pytest
from unittest.mock import patch, MagicMock, call
from repositories.article_repository import ArticleRepository

ARTICLES = [
    {"id": "1", "title": "First", "category": "sports"},
    {"id": "2", "title": "Second", "category": "sports"},
]


@pytest.fixture
def repo():
    return ArticleRepository()


# ---------------------------------------------------------------------------
# MARK: - save_articles / get_articles
# ---------------------------------------------------------------------------

class TestSaveAndGetArticles:

    def test_round_trip(self, repo):
        captured = {}

        def fake_write(path, data, cache_control="public, max-age=1800"):
            captured["path"] = path
            captured["data"] = data

        def fake_read(path):
            if path == captured.get("path"):
                return captured["data"]
            return None

        with patch("repositories.article_repository.write_json", fake_write), \
             patch("repositories.article_repository.read_json", fake_read):
            repo.save_articles("sports", ARTICLES)
            result = repo.get_articles("sports")

        assert result == ARTICLES

    def test_path_uses_category_slug(self, repo):
        with patch("repositories.article_repository.write_json") as mock_write, \
             patch("repositories.article_repository.read_json", return_value=None):
            repo.save_articles("arts-culture", [])
            path_arg = mock_write.call_args[0][0]
            assert path_arg == "articles/arts-culture.json"

    def test_saved_data_includes_metadata(self, repo):
        saved = {}

        def fake_write(path, data, cache_control="public, max-age=1800"):
            saved.update(data)

        with patch("repositories.article_repository.write_json", fake_write):
            repo.save_articles("campus", ARTICLES)

        assert saved["category"] == "campus"
        assert saved["count"] == len(ARTICLES)
        assert "cached_at" in saved
        assert saved["articles"] == ARTICLES

    def test_get_articles_returns_empty_list_when_file_missing(self, repo):
        with patch("repositories.article_repository.read_json", return_value=None):
            result = repo.get_articles("column")
        assert result == []

    def test_get_articles_returns_empty_list_when_articles_key_missing(self, repo):
        with patch("repositories.article_repository.read_json", return_value={"category": "all"}):
            result = repo.get_articles("all")
        assert result == []

    def test_get_articles_returns_empty_list_on_read_error(self, repo):
        with patch("repositories.article_repository.read_json", side_effect=Exception("GCS down")):
            result = repo.get_articles("sports")
        assert result == []

    def test_save_empty_article_list_does_not_raise(self, repo):
        with patch("repositories.article_repository.write_json") as mock_write:
            repo.save_articles("opinion", [])
            saved_data = mock_write.call_args[0][1]
            assert saved_data["count"] == 0
            assert saved_data["articles"] == []

    def test_save_raises_on_write_error(self, repo):
        with patch("repositories.article_repository.write_json", side_effect=Exception("write failed")):
            with pytest.raises(Exception, match="write failed"):
                repo.save_articles("all", ARTICLES)

    def test_get_articles_with_many_categories(self, repo):
        categories = ["all", "campus", "sports", "opinion", "features",
                      "arts-culture", "science-tech", "editorial", "column"]
        for cat in categories:
            data = {"articles": [{"id": cat}], "count": 1}
            with patch("repositories.article_repository.read_json", return_value=data):
                result = repo.get_articles(cat)
                assert result == [{"id": cat}]


# ---------------------------------------------------------------------------
# MARK: - is_stale
# ---------------------------------------------------------------------------

class TestIsStale:

    def test_returns_true_when_file_missing(self, repo):
        with patch("repositories.article_repository.file_age_seconds", return_value=None):
            assert repo.is_stale("all") is True

    def test_returns_false_when_file_is_fresh(self, repo):
        # 100 seconds old, TTL 1800
        with patch("repositories.article_repository.file_age_seconds", return_value=100.0):
            assert repo.is_stale("all", ttl_seconds=1800) is False

    def test_returns_true_when_file_older_than_ttl(self, repo):
        # 1801 seconds old, TTL 1800
        with patch("repositories.article_repository.file_age_seconds", return_value=1801.0):
            assert repo.is_stale("all", ttl_seconds=1800) is True

    def test_returns_false_just_under_ttl_boundary(self, repo):
        # 1799 seconds old, TTL 1800
        with patch("repositories.article_repository.file_age_seconds", return_value=1799.0):
            assert repo.is_stale("all", ttl_seconds=1800) is False

    def test_returns_true_at_exactly_ttl(self, repo):
        # 1800 seconds old is NOT stale (> not >=), so False
        with patch("repositories.article_repository.file_age_seconds", return_value=1800.0):
            assert repo.is_stale("all", ttl_seconds=1800) is False

    def test_returns_true_one_second_past_ttl(self, repo):
        with patch("repositories.article_repository.file_age_seconds", return_value=1800.1):
            assert repo.is_stale("all", ttl_seconds=1800) is True

    def test_returns_true_on_file_age_exception(self, repo):
        with patch("repositories.article_repository.file_age_seconds", side_effect=Exception("err")):
            assert repo.is_stale("all") is True

    def test_uses_correct_gcs_path(self, repo):
        calls = []

        def fake_age(path):
            calls.append(path)
            return 0.0

        with patch("repositories.article_repository.file_age_seconds", fake_age):
            repo.is_stale("science-tech")

        assert calls == ["articles/science-tech.json"]

    def test_default_ttl_is_30_minutes(self, repo):
        # 1799s → not stale with default TTL of 1800
        with patch("repositories.article_repository.file_age_seconds", return_value=1799.0):
            assert repo.is_stale("all") is False
        # 1801s → stale
        with patch("repositories.article_repository.file_age_seconds", return_value=1801.0):
            assert repo.is_stale("all") is True


# ---------------------------------------------------------------------------
# MARK: - count
# ---------------------------------------------------------------------------

class TestCount:

    def test_returns_count_from_file(self, repo):
        with patch("repositories.article_repository.read_json", return_value={"count": 17}):
            assert repo.count("all") == 17

    def test_returns_zero_when_file_missing(self, repo):
        with patch("repositories.article_repository.read_json", return_value=None):
            assert repo.count("sports") == 0

    def test_returns_zero_when_count_key_absent(self, repo):
        with patch("repositories.article_repository.read_json", return_value={"articles": []}):
            assert repo.count("all") == 0

    def test_returns_zero_on_read_error(self, repo):
        with patch("repositories.article_repository.read_json", side_effect=Exception("fail")):
            assert repo.count("all") == 0

    def test_default_category_is_all(self, repo):
        calls = []

        def fake_read(path):
            calls.append(path)
            return {"count": 5}

        with patch("repositories.article_repository.read_json", fake_read):
            repo.count()

        assert calls == ["articles/all.json"]
