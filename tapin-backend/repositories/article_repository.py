#
#  article_repository.py
#  TapInApp - Backend Server
#
#  MARK: - Article Firestore Repository
#  Caches fetched article lists in Firestore, keyed by category slug.
#  Mirrors event_repository.py pattern.
#
#  Collection: cached_articles
#  Document ID: category slug (e.g. "all", "campus")
#  Fields: { articles: [...], cached_at: Timestamp }
#

import logging
from datetime import datetime, timezone, timedelta

from services.firestore_client import get_firestore_client

logger = logging.getLogger(__name__)

COLLECTION = "cached_articles"
DEFAULT_TTL_MINUTES = 30


class ArticleRepository:

    # --------------------------------------------------------------------------
    # MARK: - Write
    # --------------------------------------------------------------------------

    def save_articles(self, category: str, articles: list[dict]) -> None:
        """Upserts the article list for a category into Firestore."""
        try:
            db = get_firestore_client()
            db.collection(COLLECTION).document(category).set({
                "articles":  articles,
                "cached_at": datetime.now(tz=timezone.utc),
                "category":  category,
                "count":     len(articles),
            })
            logger.info(f"Cached {len(articles)} articles for category '{category}'")
        except Exception as e:
            logger.error(f"Failed to save articles for '{category}': {e}")
            raise

    # --------------------------------------------------------------------------
    # MARK: - Read
    # --------------------------------------------------------------------------

    def get_articles(self, category: str) -> list[dict]:
        """Returns cached articles for a category, or [] if not cached."""
        try:
            db = get_firestore_client()
            doc = db.collection(COLLECTION).document(category).get()
            if not doc.exists:
                return []
            data = doc.to_dict()
            return data.get("articles", [])
        except Exception as e:
            logger.error(f"Failed to fetch articles for '{category}': {e}")
            return []

    def is_stale(self, category: str, ttl_minutes: int = DEFAULT_TTL_MINUTES) -> bool:
        """
        Returns True if the cache is missing or older than ttl_minutes.
        Returns True on any error (forces a refresh).
        """
        try:
            db = get_firestore_client()
            doc = db.collection(COLLECTION).document(category).get()
            if not doc.exists:
                return True
            data = doc.to_dict()
            cached_at = data.get("cached_at")
            if cached_at is None:
                return True

            # Firestore may return a DatetimeWithNanoseconds
            if hasattr(cached_at, "ToDatetime"):
                cached_at = cached_at.ToDatetime(tzinfo=timezone.utc)
            elif isinstance(cached_at, datetime) and cached_at.tzinfo is None:
                cached_at = cached_at.replace(tzinfo=timezone.utc)

            age = datetime.now(tz=timezone.utc) - cached_at
            return age > timedelta(minutes=ttl_minutes)

        except Exception as e:
            logger.error(f"Staleness check failed for '{category}': {e}")
            return True

    def count(self, category: str = "all") -> int:
        """Returns the cached article count for a category."""
        try:
            db = get_firestore_client()
            doc = db.collection(COLLECTION).document(category).get()
            if not doc.exists:
                return 0
            return doc.to_dict().get("count", 0)
        except Exception:
            return 0


# Singleton
article_repository = ArticleRepository()
