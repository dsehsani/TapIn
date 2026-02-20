#
#  article_repository.py
#  TapInApp - Backend Server
#
#  MARK: - Article GCS Repository
#  Caches fetched article lists in Cloud Storage, keyed by category slug.
#
#  Bucket path: articles/{category}.json
#  Schema: { articles: [...], cached_at: str, category: str, count: int }
#

import logging
from datetime import datetime, timezone

from services.gcs_client import write_json, read_json, file_age_seconds

logger = logging.getLogger(__name__)

DEFAULT_TTL_SECONDS = 30 * 60  # 30 minutes


def _path(category: str) -> str:
    return f"articles/{category}.json"


class ArticleRepository:

    # --------------------------------------------------------------------------
    # MARK: - Write
    # --------------------------------------------------------------------------

    def save_articles(self, category: str, articles: list[dict]) -> None:
        """Writes the article list for a category to GCS as a JSON file."""
        try:
            write_json(_path(category), {
                "articles":  articles,
                "cached_at": datetime.now(tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
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
            data = read_json(_path(category))
            if data is None:
                return []
            return data.get("articles", [])
        except Exception as e:
            logger.error(f"Failed to fetch articles for '{category}': {e}")
            return []

    def is_stale(self, category: str, ttl_seconds: int = DEFAULT_TTL_SECONDS) -> bool:
        """
        Returns True if the cache file is missing or older than ttl_seconds.
        Returns True on any error (forces a refresh).
        Uses GCS file modification time — no need to parse cached_at from JSON.
        """
        try:
            age = file_age_seconds(_path(category))
            if age is None:
                return True  # File doesn't exist
            return age > ttl_seconds
        except Exception as e:
            logger.error(f"Staleness check failed for '{category}': {e}")
            return True

    def count(self, category: str = "all") -> int:
        """Returns the cached article count for a category."""
        try:
            data = read_json(_path(category))
            if data is None:
                return 0
            return data.get("count", 0)
        except Exception:
            return 0


# Singleton
article_repository = ArticleRepository()
