#
#  article_content_repository.py
#  TapInApp - Backend Server
#
#  MARK: - Article Content GCS Repository
#  Caches full scraped article bodies in Cloud Storage, keyed by article ID.
#  Article content is permanent (no TTL) — articles don't change after publish.
#  First scrape is shared across all users; subsequent requests hit GCS cache.
#
#  Bucket path: article-content/{article_id}.json
#  Schema:
#    {
#      "id": str,
#      "title": str,
#      "author": str,
#      "authorEmail": str | null,
#      "publishDate": str,   # ISO 8601
#      "category": str,
#      "thumbnailURL": str | null,
#      "bodyParagraphs": [str],
#      "articleURL": str,
#      "scrapedAt": str      # ISO 8601
#    }
#

import logging
from datetime import datetime, timezone
from typing import Optional

from services.gcs_client import write_json, read_json

logger = logging.getLogger(__name__)


def _path(article_id: str) -> str:
    return f"article-content/{article_id}.json"


class ArticleContentRepository:

    # --------------------------------------------------------------------------
    # MARK: - Write
    # --------------------------------------------------------------------------

    def save_article_content(self, article_id: str, content: dict) -> None:
        """
        Saves a scraped article body to GCS.
        Content should match the ArticleContent schema above.
        Uses no-cache so CDN always returns the stored version (content is immutable).
        """
        try:
            content["scrapedAt"] = datetime.now(tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
            # Articles are immutable after publish — cache indefinitely
            write_json(_path(article_id), content, cache_control="public, max-age=86400")
            logger.info(f"Cached article content for '{article_id}'")
        except Exception as e:
            logger.error(f"Failed to save article content for '{article_id}': {e}")
            raise

    # --------------------------------------------------------------------------
    # MARK: - Read
    # --------------------------------------------------------------------------

    def get_article_content(self, article_id: str) -> Optional[dict]:
        """
        Returns cached article content dict, or None if not yet scraped.
        """
        try:
            return read_json(_path(article_id))
        except Exception as e:
            logger.error(f"Failed to fetch article content for '{article_id}': {e}")
            return None


# Singleton
article_content_repository = ArticleContentRepository()
