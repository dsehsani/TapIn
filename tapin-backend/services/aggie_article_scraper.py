#
#  aggie_article_scraper.py
#  TapInApp - Backend Server
#
#  MARK: - Aggie Article Scraper
#  Python port of AggieArticleParser.swift using BeautifulSoup.
#  Fetches a full Aggie article page and extracts structured content
#  matching the ArticleContent model consumed by the iOS app.
#
#  Extracted fields:
#    title, author, authorEmail, publishDate, category,
#    thumbnailURL, bodyParagraphs, articleURL
#

import re
import logging
import requests
from typing import Optional
from bs4 import BeautifulSoup

logger = logging.getLogger(__name__)

# Timeout for fetching the article HTML
REQUEST_TIMEOUT = 10

# Noise phrases that indicate footer/promo paragraphs to discard
_NOISE_PATTERNS = [
    "follow us on",
    "subscribe to",
    "support the aggie",
    "written by",
    "©",
]

# WordPress content container selectors, tried in priority order
_CONTENT_SELECTORS = [
    ".entry-content",
    ".post-content",
    ".article-content",
    "article .content",
]


# ------------------------------------------------------------------------------
# MARK: - Public API
# ------------------------------------------------------------------------------

def scrape_article(article_url: str, fallback: dict) -> Optional[dict]:
    """
    Fetches `article_url` and returns a dict matching the ArticleContent schema,
    or None if fetching / parsing fails.

    `fallback` should be the NewsArticle dict with: title, author, category,
    imageURL, publishDate, articleURL.
    """
    try:
        resp = requests.get(article_url, timeout=REQUEST_TIMEOUT, headers={
            "User-Agent": "TapIn/1.0 (iOS; UC Davis)"
        })
        resp.raise_for_status()
    except Exception as e:
        logger.error(f"Failed to fetch article '{article_url}': {e}")
        return None

    try:
        return _parse_html(resp.text, article_url, fallback)
    except Exception as e:
        logger.error(f"Failed to parse article '{article_url}': {e}")
        return None


# ------------------------------------------------------------------------------
# MARK: - HTML Parsing
# ------------------------------------------------------------------------------

def _parse_html(html: str, article_url: str, fallback: dict) -> Optional[dict]:
    doc = BeautifulSoup(html, "html.parser")

    # --- Title ---
    title = (
        _text(doc.select_one("h1.post-title"))
        or _text(doc.select_one("article h1"))
        or _text(doc.select_one("h1.entry-title"))
        or fallback.get("title", "")
    )

    # --- Author ---
    # Scan first 6 <p> tags for "By NAME" byline (most reliable for The Aggie)
    raw_author = (
        _extract_byline_from_content(doc)
        or _text(doc.select_one(".author-name"))
        or _text(doc.select_one(".entry-author"))
        or _text(doc.select_one(".author.vcard a"))
        or _text(doc.select_one(".byline a"))
        or _text(doc.select_one(".entry-meta .author"))
        or fallback.get("author", "The Aggie")
    )
    author_name, author_email = _parse_author_line(raw_author, fallback.get("author", "The Aggie"))

    # --- Category ---
    category = (
        _text(doc.select_one("a[rel='category tag']"))
        or _text(doc.select_one(".cat-links a"))
        or fallback.get("category", "")
    )

    # --- Thumbnail ---
    thumbnail_url = (
        _attr(doc.select_one(".post-thumbnail img"), "src")
        or _attr(doc.select_one("img.wp-post-image"), "src")
        or _attr(doc.select_one("article img"), "src")
        or fallback.get("imageURL")
    )

    # --- Body Paragraphs ---
    body_paragraphs = _extract_body_paragraphs(doc)
    if not body_paragraphs:
        logger.warning(f"No body paragraphs found for '{article_url}'")
        return None

    return {
        "title":          title,
        "author":         author_name,
        "authorEmail":    author_email,
        "publishDate":    fallback.get("publishDate", ""),
        "category":       category,
        "thumbnailURL":   thumbnail_url,
        "bodyParagraphs": body_paragraphs,
        "articleURL":     article_url,
    }


# ------------------------------------------------------------------------------
# MARK: - Body Paragraph Extraction
# ------------------------------------------------------------------------------

def _extract_body_paragraphs(doc: BeautifulSoup) -> list[str]:
    """
    Finds the main content container and extracts clean paragraph strings.
    Mirrors the iOS extractBodyParagraphs logic exactly.
    """
    container = None
    for selector in _CONTENT_SELECTORS:
        container = doc.select_one(selector)
        if container:
            break

    root = container or doc.find("article") or doc.body

    if root is None:
        return []

    paragraphs = root.find_all("p")
    cleaned = []

    for p in paragraphs:
        text = _extract_text_preserving_bold(p).strip()

        if len(text) <= 20:
            continue

        lower = text.lower()

        # Filter out byline paragraphs ("By NAME — email")
        if lower.startswith("by "):
            continue

        if any(lower.startswith(noise) or noise in lower for noise in _NOISE_PATTERNS):
            continue

        cleaned.append(text)

    return cleaned


def _extract_text_preserving_bold(tag) -> str:
    """
    Converts a <p> element's inner HTML to plain text, wrapping
    <strong>/<b> content with **markdown** to match iOS output.
    Decodes common HTML entities.
    """
    # Get the inner HTML as a string
    inner = tag.decode_contents()

    # Wrap <strong>/<b> content in **
    inner = re.sub(r"<(strong|b)[^>]*>", "**", inner, flags=re.IGNORECASE)
    inner = re.sub(r"</(strong|b)>", "**", inner, flags=re.IGNORECASE)

    # Strip all remaining HTML tags
    inner = re.sub(r"<[^>]+>", "", inner)

    # Tighten ** markers — "** text **" → "**text**"
    inner = re.sub(r"\*\*\s+", "**", inner)
    inner = re.sub(r"\s+\*\*", "**", inner)

    # Decode common HTML entities (and BS4-decoded Unicode equivalents)
    replacements = {
        "&amp;":   "&",
        "&lt;":    "<",
        "&gt;":    ">",
        "&quot;":  '"',
        "&nbsp;":  " ",
        "&#160;":  " ",
        "\xa0":    " ",  # non-breaking space already decoded by BeautifulSoup
        "&#8220;": "\u201C",
        "&#8221;": "\u201D",
        "&#8216;": "\u2018",
        "&#8217;": "\u2019",
        "&#8230;": "\u2026",
        "&#38;":   "&",
    }
    for entity, char in replacements.items():
        inner = inner.replace(entity, char)

    return inner


# ------------------------------------------------------------------------------
# MARK: - Byline Extraction
# ------------------------------------------------------------------------------

def _extract_byline_from_content(doc: BeautifulSoup) -> Optional[str]:
    """
    Scans the first 6 <p> elements for a "By NAME" byline.
    The Aggie always puts the byline as the first/second paragraph.
    """
    for i, p in enumerate(doc.find_all("p")):
        if i >= 6:
            break
        text = p.get_text(strip=True)
        if text.lower().startswith("by "):
            return text
    return None


def _parse_author_line(raw: str, fallback: str) -> tuple[str, Optional[str]]:
    """
    Parses "By AALIYAH ESPAÑOL-RIVAS — campus@theaggie.org" into (name, email).
    Mirrors AggieArticleParser.parseAuthorLine exactly.
    """
    cleaned = re.sub(r"^by\s+", "", raw, flags=re.IGNORECASE).strip()

    if "—" in cleaned:
        parts = cleaned.split("—", 1)
        name = parts[0].strip()
        email = parts[1].strip() if len(parts) > 1 else None
        return (name if name else fallback, email if email else None)

    return (cleaned if cleaned else fallback, None)


# ------------------------------------------------------------------------------
# MARK: - Helpers
# ------------------------------------------------------------------------------

def _text(tag) -> Optional[str]:
    """Returns stripped text of a tag, or None if tag is None or empty."""
    if tag is None:
        return None
    t = tag.get_text(strip=True)
    return t if t else None


def _attr(tag, attr: str) -> Optional[str]:
    """Returns an attribute value from a tag, or None."""
    if tag is None:
        return None
    val = tag.get(attr, "").strip()
    return val if val else None
