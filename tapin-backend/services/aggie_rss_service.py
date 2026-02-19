#
#  aggie_rss_service.py
#  TapInApp - Backend Server
#
#  MARK: - Aggie RSS Fetcher & Parser
#  Fetches The California Aggie RSS feeds and returns structured article dicts.
#  Mirrors the aggie_life_service.py pattern.
#
#  Article dict shape (matches iOS NewsArticle JSON decoding):
#    { id, title, excerpt, imageURL, category, publishDate, author, readTime, articleURL }
#

import re
import hashlib
import logging
import urllib.request
from datetime import datetime, timezone

import feedparser

logger = logging.getLogger(__name__)

BASE_URL = "https://theaggie.org"

CATEGORY_FEEDS = {
    "all":           f"{BASE_URL}/feed/",
    "campus":        f"{BASE_URL}/category/campus/feed/",
    "city":          f"{BASE_URL}/category/city/feed/",
    "opinion":       f"{BASE_URL}/category/opinion/feed/",
    "features":      f"{BASE_URL}/category/features/feed/",
    "arts-culture":  f"{BASE_URL}/category/arts-culture/feed/",
    "sports":        f"{BASE_URL}/category/sports/feed/",
    "science-tech":  f"{BASE_URL}/category/science-technology/feed/",
    "editorial":     f"{BASE_URL}/category/editorial/feed/",
    "column":        f"{BASE_URL}/category/column/feed/",
}

CATEGORY_DISPLAY = {
    "all":          "All News",
    "campus":       "Campus",
    "city":         "City",
    "opinion":      "Opinion",
    "features":     "Features",
    "arts-culture": "Arts & Culture",
    "sports":       "Sports",
    "science-tech": "Science & Tech",
    "editorial":    "Editorial",
    "column":       "Column",
}

WORDS_PER_MINUTE = 200


# ------------------------------------------------------------------------------
# MARK: - Public API
# ------------------------------------------------------------------------------

def fetch_articles(category: str = "all") -> list[dict]:
    """
    Fetches and parses articles from The Aggie RSS feed for the given category slug.
    Returns a list of article dicts sorted newest-first.
    """
    feed_url = CATEGORY_FEEDS.get(category, CATEGORY_FEEDS["all"])
    display_name = CATEGORY_DISPLAY.get(category, "All News")

    try:
        feed = feedparser.parse(feed_url)
    except Exception as e:
        logger.error(f"feedparser failed for {feed_url}: {e}")
        return []

    articles = []
    for entry in feed.entries:
        article = _parse_entry(entry, default_category=display_name)
        if article:
            articles.append(article)

    # Sort newest first
    articles.sort(key=lambda a: a["publishDate"], reverse=True)
    return articles


# ------------------------------------------------------------------------------
# MARK: - Entry Parsing
# ------------------------------------------------------------------------------

def _parse_entry(entry, default_category: str) -> dict | None:
    title = getattr(entry, "title", "").strip()
    link = getattr(entry, "link", "").strip()

    if not title or not link:
        return None

    # Deterministic ID from article URL
    article_id = hashlib.sha256(link.encode()).hexdigest()[:32]

    # Author
    author = (
        getattr(entry, "author", None)
        or (entry.get("dc_creator") if hasattr(entry, "get") else None)
        or "The Aggie"
    )

    # Category
    tags = getattr(entry, "tags", [])
    category = tags[0].term if tags else default_category

    # Publish date → ISO 8601 string
    publish_date = _parse_date(entry)

    # Excerpt — strip HTML tags from the RSS description
    raw_summary = getattr(entry, "summary", "") or ""
    excerpt = _strip_html(raw_summary)[:300]

    # Read time — estimate from content word count
    content = ""
    if hasattr(entry, "content") and entry.content:
        content = entry.content[0].get("value", "")
    elif hasattr(entry, "summary_detail"):
        content = entry.summary_detail.get("value", "")
    word_count = len(_strip_html(content).split())
    read_time = max(1, round(word_count / WORDS_PER_MINUTE))

    # Image URL — try media thumbnail, then enclosure, then scrape
    image_url = _extract_image(entry)

    return {
        "id":          article_id,
        "title":       title,
        "excerpt":     excerpt,
        "imageURL":    image_url,
        "category":    category,
        "publishDate": publish_date,
        "author":      author,
        "readTime":    read_time,
        "articleURL":  link,
    }


# ------------------------------------------------------------------------------
# MARK: - Helpers
# ------------------------------------------------------------------------------

def _parse_date(entry) -> str:
    """Returns ISO 8601 UTC string from feedparser's parsed date or now."""
    if hasattr(entry, "published_parsed") and entry.published_parsed:
        try:
            dt = datetime(*entry.published_parsed[:6], tzinfo=timezone.utc)
            return dt.strftime("%Y-%m-%dT%H:%M:%SZ")
        except Exception:
            pass
    return datetime.now(tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _extract_image(entry) -> str:
    """Extracts image URL from media thumbnail, enclosure, or content."""
    # feedparser media:thumbnail
    if hasattr(entry, "media_thumbnail") and entry.media_thumbnail:
        return entry.media_thumbnail[0].get("url", "")

    # RSS enclosure
    if hasattr(entry, "enclosures") and entry.enclosures:
        for enc in entry.enclosures:
            if enc.get("type", "").startswith("image/"):
                return enc.get("url", "")

    # Scrape first <img> from content:encoded
    content = ""
    if hasattr(entry, "content") and entry.content:
        content = entry.content[0].get("value", "")
    if content:
        match = re.search(r'<img[^>]+src=["\']([^"\']+)["\']', content, re.IGNORECASE)
        if match:
            return match.group(1)

    return ""


def _strip_html(html: str) -> str:
    """Removes HTML tags and decodes common entities."""
    text = re.sub(r"<[^>]+>", " ", html)
    text = re.sub(r"&amp;", "&", text)
    text = re.sub(r"&lt;", "<", text)
    text = re.sub(r"&gt;", ">", text)
    text = re.sub(r"&quot;", '"', text)
    text = re.sub(r"&#?\w+;", " ", text)
    return re.sub(r"\s+", " ", text).strip()
