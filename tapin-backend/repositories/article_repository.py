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
        """
        Merges new articles into the persistent archive for a category.
        New articles from RSS are prepended; duplicates (by id) are skipped.
        The cached_at timestamp tracks when we last fetched from RSS.
        """
        try:
            db = get_firestore_client()
            doc_ref = db.collection(COLLECTION).document(category)
            doc = doc_ref.get()

            # Build a set of existing article IDs for fast dedup
            existing_articles = []
            if doc.exists:
                existing_articles = doc.to_dict().get("articles", [])
            existing_ids = {a.get("id") for a in existing_articles if a.get("id")}

            # Find genuinely new articles
            new_articles = [a for a in articles if a.get("id") not in existing_ids]

            # Prepend new articles to the archive (newest first)
            merged = new_articles + existing_articles

            doc_ref.set({
                "articles":  merged,
                "cached_at": datetime.now(tz=timezone.utc),
                "category":  category,
                "count":     len(merged),
            })

            if new_articles:
                logger.info(f"Added {len(new_articles)} new articles for '{category}' (total: {len(merged)})")
            else:
                logger.info(f"No new articles for '{category}', refreshed timestamp (total: {len(merged)})")
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

    # Topic → expanded keywords so general topics match Aggie categories
    TOPIC_EXPANSIONS = {
        "technology":    ["tech", "sciencetech", "science", "computer", "software", "ai"],
        "entertainment": ["film", "movie", "music", "show", "concert", "arts", "theater", "comedy"],
        "politics":      ["political", "election", "vote", "government", "policy", "legislation", "senate", "congress"],
        "business":      ["economy", "economic", "startup", "finance", "company", "market", "job"],
        "food & dining": ["food", "dining", "restaurant", "recipe", "chef", "eat", "menu", "cafe"],
        "campus life":   ["campus", "student", "dorm", "quad", "aggie", "uc davis", "university"],
        "health":        ["health", "medical", "hospital", "wellness", "mental", "clinic", "disease"],
        "science":       ["science", "sciencetech", "research", "study", "lab", "discovery"],
        "sports":        ["sports", "game", "basketball", "football", "soccer", "tennis", "athlete", "team"],
        "arts":          ["arts", "art", "gallery", "museum", "painting", "theater", "dance", "culture"],
    }

    def search_articles(self, query: str, limit: int = 50) -> list[dict]:
        """
        Searches across ALL category archives for articles matching the query.
        Matches against title, excerpt, category, and author fields.
        Returns deduplicated results sorted by relevance (title match > excerpt).
        """
        if not query or not query.strip():
            return []

        query_lower = query.lower().strip()
        query_words = query_lower.split()

        # Expand query with topic synonyms
        expanded = list(query_words)
        for topic, synonyms in self.TOPIC_EXPANSIONS.items():
            if query_lower == topic or query_lower in synonyms:
                expanded.extend(s for s in synonyms if s not in expanded)
                break
        query_words = expanded

        try:
            db = get_firestore_client()
            docs = db.collection(COLLECTION).stream()

            seen_ids = set()
            scored_articles = []

            for doc in docs:
                data = doc.to_dict()
                for article in data.get("articles", []):
                    article_id = article.get("id", "")
                    if article_id in seen_ids:
                        continue
                    seen_ids.add(article_id)

                    title = (article.get("title") or "").lower()
                    excerpt = (article.get("excerpt") or "").lower()
                    category = (article.get("category") or "").lower()
                    author = (article.get("author") or "").lower()

                    score = 0
                    for word in query_words:
                        if word in title:
                            score += 3
                        if word in category:
                            score += 2
                        if word in excerpt:
                            score += 1
                        if word in author:
                            score += 1

                    if score > 0:
                        scored_articles.append((score, article))

            # Sort by score descending, then take top results
            scored_articles.sort(key=lambda x: x[0], reverse=True)
            return [a for _, a in scored_articles[:limit]]

        except Exception as e:
            logger.error(f"Search failed for query '{query}': {e}")
            return []

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
