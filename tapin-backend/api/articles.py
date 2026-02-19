#
#  articles.py
#  TapInApp - Backend Server
#
#  MARK: - Articles API Blueprint
#
#  Endpoints:
#  GET  /api/articles?category=all  - Returns cached article list (refreshes if stale)
#  POST /api/articles/refresh       - Forces re-fetch from The Aggie RSS
#  GET  /api/articles/health        - Health check + cache stats
#
#  Cache flow:
#    1. Check Firestore for cached articles (TTL: 30 min)
#    2. Cache hit → return immediately
#    3. Cache miss → fetch from aggie_rss_service → write to Firestore → return
#

import os
import logging
from flask import Blueprint, jsonify, request
from repositories.article_repository import article_repository
from services.aggie_rss_service import fetch_articles, CATEGORY_FEEDS

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
    Automatically refreshes from RSS if the cache is stale (>30 min).

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
# MARK: - POST /api/articles/refresh
# ------------------------------------------------------------------------------

@articles_bp.route("/refresh", methods=["POST"])
def refresh_articles():
    """
    Forces a re-fetch from The Aggie RSS for all categories (or one if specified).
    Protected by X-Refresh-Secret header (same secret as events).

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
    """Health check — Firestore connectivity and cached article counts."""
    try:
        from services.firestore_client import is_firestore_connected
        firestore_ok = is_firestore_connected()

        counts = {}
        if firestore_ok:
            for cat in ["all", "campus", "sports"]:
                counts[cat] = article_repository.count(cat)

        return jsonify({
            "status":    "healthy",
            "service":   "articles",
            "firestore": "connected" if firestore_ok else "disconnected",
            "cached_counts": counts,
        }), 200

    except Exception as e:
        return jsonify({
            "status":  "degraded",
            "service": "articles",
            "error":   str(e),
        }), 200
