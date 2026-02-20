"""
test_articles_api.py — Flask client tests for api/articles.py

All service/repository calls are patched so no real GCS or network calls happen.
"""

import pytest
import json
from urllib.parse import quote
from unittest.mock import patch, MagicMock

ARTICLE = {
    "id": "a" * 32,
    "title": "Test Article",
    "excerpt": "Test excerpt.",
    "imageURL": "https://theaggie.org/img.jpg",
    "category": "campus",
    "publishDate": "2026-02-19T10:00:00Z",
    "author": "Jane Doe",
    "readTime": 3,
    "articleURL": "https://theaggie.org/2026/02/19/test/",
}

CONTENT = {
    "title": "Full Article",
    "author": "John Doe",
    "authorEmail": "jdoe@ucdavis.edu",
    "publishDate": "2026-02-18T09:00:00Z",
    "category": "sports",
    "thumbnailURL": "https://theaggie.org/thumb.jpg",
    "bodyParagraphs": ["Paragraph one.", "Paragraph two."],
    "articleURL": "https://theaggie.org/article/",
}

ARTICLE_URL = "https://theaggie.org/2026/02/19/test/"


# ---------------------------------------------------------------------------
# MARK: - GET /api/articles
# ---------------------------------------------------------------------------

class TestGetArticles:

    def test_cache_hit_returns_200_with_cached_true(self, client):
        with patch("api.articles.article_repository") as repo:
            repo.is_stale.return_value = False
            repo.get_articles.return_value = [ARTICLE]

            resp = client.get("/api/articles?category=campus")

        data = resp.get_json()
        assert resp.status_code == 200
        assert data["success"] is True
        assert data["cached"] is True
        assert data["count"] == 1
        assert len(data["articles"]) == 1

    def test_cache_miss_fetches_from_rss_and_saves(self, client):
        with patch("api.articles.article_repository") as repo, \
             patch("api.articles.fetch_articles", return_value=[ARTICLE]) as mock_fetch, \
             patch("api.articles.mirror_article_image", return_value="https://gcs.url/img.jpg"):
            repo.is_stale.return_value = True

            resp = client.get("/api/articles?category=sports")

        data = resp.get_json()
        assert resp.status_code == 200
        assert data["cached"] is False
        mock_fetch.assert_called_once_with("sports")
        repo.save_articles.assert_called_once()

    def test_images_mirrored_on_cache_miss(self, client):
        articles = [dict(ARTICLE), dict(ARTICLE)]
        articles[1]["id"] = "b" * 32
        mirror_calls = []

        with patch("api.articles.article_repository") as repo, \
             patch("api.articles.fetch_articles", return_value=articles), \
             patch("api.articles.mirror_article_image",
                   side_effect=lambda aid, url: mirror_calls.append(aid) or url):
            repo.is_stale.return_value = True

            client.get("/api/articles?category=all")

        assert len(mirror_calls) == 2

    def test_images_not_mirrored_on_cache_hit(self, client):
        with patch("api.articles.article_repository") as repo, \
             patch("api.articles.mirror_article_image") as mock_mirror:
            repo.is_stale.return_value = False
            repo.get_articles.return_value = [ARTICLE]

            client.get("/api/articles?category=all")

        mock_mirror.assert_not_called()

    def test_invalid_category_defaults_to_all(self, client):
        categories_queried = []

        with patch("api.articles.article_repository") as repo:
            repo.is_stale.side_effect = lambda cat: categories_queried.append(cat) or False
            repo.get_articles.return_value = []

            client.get("/api/articles?category=notreal")

        assert categories_queried == ["all"]

    def test_missing_category_defaults_to_all(self, client):
        with patch("api.articles.article_repository") as repo:
            repo.is_stale.return_value = False
            repo.get_articles.return_value = []
            cats = []
            repo.is_stale.side_effect = lambda cat: cats.append(cat) or False

            client.get("/api/articles")

        assert cats == ["all"]

    def test_category_uppercased_normalized_to_lowercase(self, client):
        cats = []

        with patch("api.articles.article_repository") as repo:
            repo.is_stale.side_effect = lambda cat: cats.append(cat) or False
            repo.get_articles.return_value = []

            client.get("/api/articles?category=SPORTS")

        assert cats == ["sports"]

    def test_rss_fetch_failure_returns_500(self, client):
        with patch("api.articles.article_repository") as repo, \
             patch("api.articles.fetch_articles", side_effect=Exception("RSS down")):
            repo.is_stale.return_value = True

            resp = client.get("/api/articles?category=all")

        data = resp.get_json()
        assert resp.status_code == 500
        assert data["success"] is False
        assert "error" in data

    def test_empty_rss_response_does_not_save(self, client):
        with patch("api.articles.article_repository") as repo, \
             patch("api.articles.fetch_articles", return_value=[]), \
             patch("api.articles.mirror_article_image", return_value=None):
            repo.is_stale.return_value = True

            resp = client.get("/api/articles?category=all")

        repo.save_articles.assert_not_called()
        assert resp.status_code == 200

    def test_valid_category_slug_arts_culture(self, client):
        with patch("api.articles.article_repository") as repo:
            repo.is_stale.return_value = False
            repo.get_articles.return_value = []
            cats = []
            repo.is_stale.side_effect = lambda cat: cats.append(cat) or False

            resp = client.get("/api/articles?category=arts-culture")

        assert resp.status_code == 200
        assert cats == ["arts-culture"]

    def test_response_contains_required_fields(self, client):
        with patch("api.articles.article_repository") as repo:
            repo.is_stale.return_value = False
            repo.get_articles.return_value = [ARTICLE]

            resp = client.get("/api/articles")

        data = resp.get_json()
        for field in ["success", "articles", "count", "cached"]:
            assert field in data, f"Field '{field}' missing from response"


# ---------------------------------------------------------------------------
# MARK: - GET /api/articles/<article_id>/content
# ---------------------------------------------------------------------------

class TestGetArticleContent:

    def test_cache_hit_returns_200_cached_true(self, client):
        with patch("api.articles.article_content_repository") as repo:
            repo.get_article_content.return_value = CONTENT

            resp = client.get(f"/api/articles/{'a'*32}/content")

        data = resp.get_json()
        assert resp.status_code == 200
        assert data["success"] is True
        assert data["cached"] is True
        assert data["content"] == CONTENT

    def test_cache_hit_does_not_call_scraper(self, client):
        with patch("api.articles.article_content_repository") as repo, \
             patch("api.articles.scrape_article") as mock_scrape:
            repo.get_article_content.return_value = CONTENT

            client.get(f"/api/articles/{'a'*32}/content")

        mock_scrape.assert_not_called()

    def test_cache_miss_with_url_triggers_scrape(self, client):
        with patch("api.articles.article_content_repository") as repo, \
             patch("api.articles.scrape_article", return_value=CONTENT) as mock_scrape:
            repo.get_article_content.return_value = None

            resp = client.get(f"/api/articles/{'a'*32}/content?url={ARTICLE_URL}")

        data = resp.get_json()
        assert resp.status_code == 200
        assert data["cached"] is False
        mock_scrape.assert_called_once()

    def test_cache_miss_and_scrape_success_saves_to_gcs(self, client):
        with patch("api.articles.article_content_repository") as repo, \
             patch("api.articles.scrape_article", return_value=CONTENT):
            repo.get_article_content.return_value = None

            client.get(f"/api/articles/{'a'*32}/content?url={ARTICLE_URL}")

        repo.save_article_content.assert_called_once()

    def test_cache_miss_without_url_returns_400(self, client):
        with patch("api.articles.article_content_repository") as repo:
            repo.get_article_content.return_value = None

            resp = client.get(f"/api/articles/{'a'*32}/content")

        data = resp.get_json()
        assert resp.status_code == 400
        assert data["success"] is False
        assert "url" in data["error"].lower()

    def test_scrape_failure_returns_422(self, client):
        with patch("api.articles.article_content_repository") as repo, \
             patch("api.articles.scrape_article", return_value=None):
            repo.get_article_content.return_value = None

            resp = client.get(f"/api/articles/{'a'*32}/content?url={ARTICLE_URL}")

        assert resp.status_code == 422
        data = resp.get_json()
        assert data["success"] is False

    def test_gcs_save_failure_still_returns_scraped_content(self, client):
        with patch("api.articles.article_content_repository") as repo, \
             patch("api.articles.scrape_article", return_value=CONTENT):
            repo.get_article_content.return_value = None
            repo.save_article_content.side_effect = Exception("GCS write failed")

            resp = client.get(f"/api/articles/{'a'*32}/content?url={ARTICLE_URL}")

        data = resp.get_json()
        assert resp.status_code == 200
        assert data["success"] is True
        assert data["content"] is not None

    def test_article_id_129_chars_returns_400(self, client):
        long_id = "a" * 129
        resp = client.get(f"/api/articles/{long_id}/content")
        assert resp.status_code == 400

    def test_article_id_128_chars_accepted(self, client):
        good_id = "a" * 128
        with patch("api.articles.article_content_repository") as repo:
            repo.get_article_content.return_value = CONTENT
            resp = client.get(f"/api/articles/{good_id}/content")
        assert resp.status_code == 200

    def test_url_with_query_params_passed_to_scraper(self, client):
        url_with_params = "https://theaggie.org/article?foo=bar&baz=qux"
        captured_urls = []

        def fake_scrape(url, fallback):
            captured_urls.append(url)
            return CONTENT

        with patch("api.articles.article_content_repository") as repo, \
             patch("api.articles.scrape_article", fake_scrape):
            repo.get_article_content.return_value = None
            client.get(f"/api/articles/{'a'*32}/content?url={quote(url_with_params, safe='')}")

        assert captured_urls[0] == url_with_params

    def test_cache_hit_with_url_param_still_returns_cached(self, client):
        """If cache hits, scraper is NOT called even if url param is provided."""
        with patch("api.articles.article_content_repository") as repo, \
             patch("api.articles.scrape_article") as mock_scrape:
            repo.get_article_content.return_value = CONTENT

            resp = client.get(f"/api/articles/{'a'*32}/content?url={ARTICLE_URL}")

        assert resp.status_code == 200
        assert resp.get_json()["cached"] is True
        mock_scrape.assert_not_called()


# ---------------------------------------------------------------------------
# MARK: - POST /api/articles/refresh
# ---------------------------------------------------------------------------

class TestRefreshArticles:

    def test_no_secret_set_allows_unauthenticated(self, client, monkeypatch):
        monkeypatch.delenv("REFRESH_SECRET", raising=False)
        with patch("api.articles.fetch_articles", return_value=[ARTICLE]), \
             patch("api.articles.article_repository") as repo, \
             patch("api.articles.mirror_article_image", return_value=None):
            resp = client.post("/api/articles/refresh", json={})
        assert resp.status_code == 200

    def test_valid_secret_returns_200(self, client, monkeypatch):
        monkeypatch.setenv("REFRESH_SECRET", "test-secret")
        with patch("api.articles.fetch_articles", return_value=[ARTICLE]), \
             patch("api.articles.article_repository"), \
             patch("api.articles.mirror_article_image", return_value=None):
            resp = client.post("/api/articles/refresh", json={},
                               headers={"X-Refresh-Secret": "test-secret"})
        assert resp.status_code == 200

    def test_wrong_secret_returns_401(self, client, monkeypatch):
        monkeypatch.setenv("REFRESH_SECRET", "test-secret")
        resp = client.post("/api/articles/refresh", json={},
                           headers={"X-Refresh-Secret": "wrong"})
        assert resp.status_code == 401
        assert resp.get_json()["success"] is False

    def test_missing_secret_header_returns_401(self, client, monkeypatch):
        monkeypatch.setenv("REFRESH_SECRET", "test-secret")
        resp = client.post("/api/articles/refresh", json={})
        assert resp.status_code == 401

    def test_body_with_specific_category_refreshes_only_that_category(self, client, monkeypatch):
        monkeypatch.delenv("REFRESH_SECRET", raising=False)
        fetched_cats = []

        def fake_fetch(cat):
            fetched_cats.append(cat)
            return [ARTICLE]

        with patch("api.articles.fetch_articles", fake_fetch), \
             patch("api.articles.article_repository"), \
             patch("api.articles.mirror_article_image", return_value=None):
            resp = client.post("/api/articles/refresh", json={"category": "sports"})

        assert resp.status_code == 200
        assert fetched_cats == ["sports"]

    def test_invalid_category_in_body_refreshes_all(self, client, monkeypatch):
        monkeypatch.delenv("REFRESH_SECRET", raising=False)
        fetched_cats = []

        def fake_fetch(cat):
            fetched_cats.append(cat)
            return []

        with patch("api.articles.fetch_articles", fake_fetch), \
             patch("api.articles.article_repository"), \
             patch("api.articles.mirror_article_image", return_value=None):
            client.post("/api/articles/refresh", json={"category": "invalid_cat"})

        assert len(fetched_cats) > 1  # All categories refreshed

    def test_one_category_failure_others_succeed(self, client, monkeypatch):
        monkeypatch.delenv("REFRESH_SECRET", raising=False)

        def fake_fetch(cat):
            if cat == "campus":
                raise Exception("RSS error")
            return [ARTICLE]

        with patch("api.articles.fetch_articles", fake_fetch), \
             patch("api.articles.article_repository"), \
             patch("api.articles.mirror_article_image", return_value=None):
            resp = client.post("/api/articles/refresh", json={})

        data = resp.get_json()
        assert resp.status_code == 200  # Still 200 even if one failed
        assert data["success"] is True
        assert "campus" in data["refreshed"]
        assert "error" in str(data["refreshed"]["campus"])

    def test_images_mirrored_during_refresh(self, client, monkeypatch):
        monkeypatch.delenv("REFRESH_SECRET", raising=False)
        mirror_calls = []

        with patch("api.articles.fetch_articles", return_value=[ARTICLE]), \
             patch("api.articles.article_repository"), \
             patch("api.articles.mirror_article_image",
                   side_effect=lambda aid, url: mirror_calls.append(aid) or url):
            client.post("/api/articles/refresh", json={"category": "sports"})

        assert len(mirror_calls) >= 1

    def test_response_contains_refreshed_dict(self, client, monkeypatch):
        monkeypatch.delenv("REFRESH_SECRET", raising=False)
        with patch("api.articles.fetch_articles", return_value=[ARTICLE]), \
             patch("api.articles.article_repository"), \
             patch("api.articles.mirror_article_image", return_value=None):
            resp = client.post("/api/articles/refresh", json={"category": "sports"})

        data = resp.get_json()
        assert "refreshed" in data
        assert "sports" in data["refreshed"]


# ---------------------------------------------------------------------------
# MARK: - GET /api/articles/health
# ---------------------------------------------------------------------------

class TestArticlesHealth:

    def test_gcs_connected_returns_healthy(self, client):
        with patch("api.articles.article_repository") as repo, \
             patch("services.gcs_client.is_gcs_connected", return_value=True):
            repo.count.return_value = 5

            resp = client.get("/api/articles/health")

        data = resp.get_json()
        assert resp.status_code == 200
        assert data["status"] == "healthy"
        assert data["gcs"] == "connected"
        assert data["storage"] == "gcs"

    def test_gcs_disconnected_still_returns_200(self, client):
        with patch("services.gcs_client.is_gcs_connected", return_value=False):
            resp = client.get("/api/articles/health")

        data = resp.get_json()
        assert resp.status_code == 200
        assert data["gcs"] == "disconnected"

    def test_cached_counts_present_when_connected(self, client):
        with patch("api.articles.article_repository") as repo, \
             patch("services.gcs_client.is_gcs_connected", return_value=True):
            repo.count.return_value = 10

            resp = client.get("/api/articles/health")

        data = resp.get_json()
        assert "cached_counts" in data
        for cat in ["all", "campus", "sports"]:
            assert cat in data["cached_counts"]

    def test_counts_not_fetched_when_gcs_disconnected(self, client):
        with patch("api.articles.article_repository") as repo, \
             patch("services.gcs_client.is_gcs_connected", return_value=False):
            resp = client.get("/api/articles/health")

        repo.count.assert_not_called()

    def test_exception_returns_degraded(self, client):
        with patch("services.gcs_client.is_gcs_connected", side_effect=Exception("crash")):
            resp = client.get("/api/articles/health")

        data = resp.get_json()
        assert resp.status_code == 200
        assert data["status"] == "degraded"
        assert "error" in data
