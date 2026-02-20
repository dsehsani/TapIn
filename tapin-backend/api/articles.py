#
#  articles.py
#  TapInApp - Backend Server
#
#  MARK: - Articles API Blueprint
#
#  Endpoints:
#  GET  /api/articles?category=all          - Returns cached article list (refreshes if stale)
#  GET  /api/articles/<article_id>/content  - Returns full article body (scrapes + caches on miss)
#  POST /api/articles/refresh               - Forces re-fetch from The Aggie RSS
#  GET  /api/articles/health                - Health check + cache stats
#
#  Cache flow (article lists):
#    1. Check GCS for articles/{category}.json (TTL: 30 min via file modification time)
#    2. Cache hit → return immediately
#    3. Cache miss → fetch from aggie_rss_service → write to GCS → return
#
#  Cache flow (article content):
#    1. Check GCS for article-content/{article_id}.json (no TTL — articles are immutable)
#    2. Cache hit → return immediately (shared across all users)
#    3. Cache miss → scrape The Aggie → write to GCS → return
#

import os
import logging
from flask import Blueprint, jsonify, request
from repositories.article_repository import article_repository
from repositories.article_content_repository import article_content_repository
from services.aggie_rss_service import fetch_articles, CATEGORY_FEEDS
from services.aggie_article_scraper import scrape_article
from services.image_mirror_service import mirror_article_image

logger = logging.getLogger(__name__)

articles_bp = Blueprint("articles", __name__, url_prefix="/api/articles")

VALID_CATEGORIES = set(CATEGORY_FEEDS.keys())


# ------------------------------------------------------------------------------
# MARK: - GET /api/articles
# ------------------------------------------------------------------------------

@articles_bp.route("", methods=["GET"])
def get_articles():
    """
    Returns cached article list for the requested category.
    Automatically refreshes from RSS if the GCS file is stale (>30 min).

    Query params:
        category (str): category slug, default "all"

    Response (200):
        {
            "success": true,
            "articles": [...],
            "count": 10,
            "cached": true
        }
    """
    category = request.args.get("category", "all").lower().strip()
    if category not in VALID_CATEGORIES:
        category = "all"

    try:
        cached = not article_repository.is_stale(category)

        if cached:
            articles = article_repository.get_articles(category)
            logger.info(f"Cache hit for '{category}': {len(articles)} articles")
        else:
            logger.info(f"Cache miss for '{category}' — fetching from RSS")
            articles = fetch_articles(category)
            if articles:
                # Mirror article images to GCS so URLs are stable
                for article in articles:
                    article_id = article.get("id", "")
                    article["imageURL"] = mirror_article_image(article_id, article.get("imageURL"))
                article_repository.save_articles(category, articles)

        return jsonify({
            "success":  True,
            "articles": articles,
            "count":    len(articles),
            "cached":   cached,
        }), 200

    except Exception as e:
        logger.error(f"GET /api/articles failed: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ------------------------------------------------------------------------------
# MARK: - GET /api/articles/<article_id>/content
# ------------------------------------------------------------------------------

@articles_bp.route("/<article_id>/content", methods=["GET"])
def get_article_content(article_id: str):
    """
    Returns the full scraped body for a specific article.
    On a cache miss, the backend scrapes The Aggie and stores the result in GCS
    so all subsequent users get the cached version.

    Path params:
        article_id (str): SHA256-derived article ID from the article list

    Query params:
        url (str): The Aggie article URL — required on a cache miss to trigger scraping

    Response (200, cached):
        { "success": true, "content": {...}, "cached": true }

    Response (200, freshly scraped):
        { "success": true, "content": {...}, "cached": false }

    Response (400):
        { "success": false, "error": "url param required on cache miss" }

    Response (422):
        { "success": false, "error": "Could not extract article content" }
    """
    if not article_id or len(article_id) > 128:
        return jsonify({"success": False, "error": "Invalid article_id"}), 400

    # Check GCS cache first (shared across all users)
    cached_content = article_content_repository.get_article_content(article_id)
    if cached_content:
        logger.info(f"Content cache hit for article '{article_id}'")
        return jsonify({"success": True, "content": cached_content, "cached": True}), 200

    # Cache miss — need the article URL to scrape
    article_url = request.args.get("url", "").strip()
    if not article_url:
        return jsonify({
            "success": False,
            "error": "url query param is required when article content is not cached"
        }), 400

    logger.info(f"Content cache miss for '{article_id}' — scraping {article_url}")

    # Scrape with empty fallback (caller should pass article metadata as needed)
    fallback = {
        "title":       "",
        "author":      "The Aggie",
        "category":    "",
        "imageURL":    "",
        "publishDate": "",
        "articleURL":  article_url,
    }
    content = scrape_article(article_url, fallback)

    if not content:
        return jsonify({
            "success": False,
            "error": "Could not extract article content"
        }), 422

    # Save to GCS so future requests are served from cache
    try:
        article_content_repository.save_article_content(article_id, content)
    except Exception as e:
        logger.error(f"Failed to cache article content for '{article_id}': {e}")
        # Still return the scraped content even if caching failed

    return jsonify({"success": True, "content": content, "cached": False}), 200


# ------------------------------------------------------------------------------
# MARK: - POST /api/articles/refresh
# ------------------------------------------------------------------------------

@articles_bp.route("/refresh", methods=["POST"])
def refresh_articles():
    """
    Forces a re-fetch from The Aggie RSS for all categories (or one if specified).
    Protected by X-Refresh-Secret header.

    Body (optional JSON):
        { "category": "campus" }   ← refresh only this category
        {}                         ← refresh all categories
    """
    secret = os.environ.get("REFRESH_SECRET", "")
    if secret:
        provided = request.headers.get("X-Refresh-Secret", "")
        if provided != secret:
            return jsonify({"success": False, "error": "Unauthorized"}), 401

    body = request.get_json(silent=True) or {}
    target = body.get("category", "").lower().strip()
    categories = [target] if target in VALID_CATEGORIES else list(VALID_CATEGORIES)

    results = {}
    for cat in categories:
        try:
            articles = fetch_articles(cat)
            if articles:
                for article in articles:
                    article_id = article.get("id", "")
                    article["imageURL"] = mirror_article_image(article_id, article.get("imageURL"))
                article_repository.save_articles(cat, articles)
            results[cat] = len(articles)
        except Exception as e:
            logger.error(f"Refresh failed for '{cat}': {e}")
            results[cat] = f"error: {e}"

    return jsonify({"success": True, "refreshed": results}), 200


# ------------------------------------------------------------------------------
# MARK: - GET /api/articles/health
# ------------------------------------------------------------------------------

@articles_bp.route("/health", methods=["GET"])
def health_check():
    """Health check — GCS connectivity and cached article counts."""
    try:
        from services.gcs_client import is_gcs_connected
        gcs_ok = is_gcs_connected()

        counts = {}
        if gcs_ok:
            for cat in ["all", "campus", "sports"]:
                counts[cat] = article_repository.count(cat)

        return jsonify({
            "status":        "healthy",
            "service":       "articles",
            "storage":       "gcs",
            "gcs":           "connected" if gcs_ok else "disconnected",
            "cached_counts": counts,
        }), 200

    except Exception as e:
        return jsonify({
            "status":  "degraded",
            "service": "articles",
            "error":   str(e),
        }), 200
