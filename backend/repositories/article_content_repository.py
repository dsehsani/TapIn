#
#  article_content_repository.py
#  TapInApp - Backend Server
#
#  MARK: - Article Content Firestore Repository
#  Caches scraped article content in Firestore, keyed by SHA-256 hash of the URL.
#  No TTL — articles don't change after publication.
#
#  Collection: cached_article_content
#  Document ID: SHA-256(url)[:32]
#  Fields: { title, author, authorEmail, publishDate, category,
#            thumbnailURL, bodyParagraphs, articleURL, cached_at }
#

import hashlib
import logging
from datetime import datetime, timezone

from services.firestore_client import get_firestore_client

logger = logging.getLogger(__name__)

COLLECTION = "cached_article_content"


class ArticleContentRepository:

    # --------------------------------------------------------------------------
    # MARK: - Helpers
    # --------------------------------------------------------------------------

    @staticmethod
    def _doc_id(url: str) -> str:
        """SHA-256 hash of URL, truncated to 32 chars (same pattern as aggie_rss_service)."""
        return hashlib.sha256(url.encode()).hexdigest()[:32]

    # --------------------------------------------------------------------------
    # MARK: - Read
    # --------------------------------------------------------------------------

    def get_content(self, url: str) -> dict | None:
        """Returns cached article content for a URL, or None if not cached."""
        try:
            db = get_firestore_client()
            doc = db.collection(COLLECTION).document(self._doc_id(url)).get()
            if not doc.exists:
                return None
            data = doc.to_dict()
            return data
        except Exception as e:
            logger.error(f"Failed to fetch content for '{url}': {e}")
            return None

    # --------------------------------------------------------------------------
    # MARK: - Write
    # --------------------------------------------------------------------------

    def save_content(self, content: dict) -> None:
        """Persists scraped article content to Firestore."""
        try:
            url = content.get("articleURL", "")
            db = get_firestore_client()
            doc_data = {**content, "cached_at": datetime.now(tz=timezone.utc)}
            db.collection(COLLECTION).document(self._doc_id(url)).set(doc_data)
            logger.info(f"Cached article content for '{url}'")
        except Exception as e:
            logger.error(f"Failed to save content: {e}")
            raise

    # --------------------------------------------------------------------------
    # MARK: - Stats
    # --------------------------------------------------------------------------

    def count(self) -> int:
        """Returns the number of cached article content documents."""
        try:
            db = get_firestore_client()
            docs = db.collection(COLLECTION).stream()
            return sum(1 for _ in docs)
        except Exception:
            return 0


# Singleton
article_content_repository = ArticleContentRepository()
