#
#  article_scraper_service.py
#  TapInApp - Backend Server
#
#  MARK: - Article Content Scraper
#  Python/BeautifulSoup port of AggieArticleParser.swift.
#  Fetches a full Aggie article page and extracts structured content
#  (title, author, body paragraphs, etc.) from The Aggie's WordPress HTML.
#

import re
import logging
import requests
from bs4 import BeautifulSoup

logger = logging.getLogger(__name__)


# --------------------------------------------------------------------------
# MARK: - Public API
# --------------------------------------------------------------------------

def scrape_article(url: str) -> dict | None:
    """
    Fetches and parses a full Aggie article page into structured content.

    Returns a dict with keys: title, author, authorEmail, publishDate,
    category, thumbnailURL, bodyParagraphs, articleURL.
    Returns None on any failure.
    """
    try:
        resp = requests.get(url, timeout=15)
        if resp.status_code != 200:
            logger.warning(f"HTTP {resp.status_code} for {url}")
            return None

        html = resp.text
        soup = BeautifulSoup(html, "html.parser")

        title = _extract_title(soup)
        author_line = _extract_author_line(soup)
        author_name, author_email = _parse_author_line(author_line)
        category = _extract_category(soup)
        thumbnail_url = _extract_thumbnail(soup)
        body_paragraphs = _extract_body_paragraphs(soup)

        if not body_paragraphs:
            logger.warning(f"No body paragraphs extracted from {url}")
            return None

        return {
            "title": title,
            "author": author_name,
            "authorEmail": author_email,
            "publishDate": None,
            "category": category,
            "thumbnailURL": thumbnail_url,
            "bodyParagraphs": body_paragraphs,
            "articleURL": url,
        }

    except Exception as e:
        logger.error(f"scrape_article failed for {url}: {e}")
        return None


# --------------------------------------------------------------------------
# MARK: - Title
# --------------------------------------------------------------------------

def _extract_title(soup: BeautifulSoup) -> str:
    for selector in ["h1.post-title", "article h1", "h1.entry-title"]:
        el = soup.select_one(selector)
        if el and el.get_text(strip=True):
            return el.get_text(strip=True)
    return ""


# --------------------------------------------------------------------------
# MARK: - Author / Byline
# --------------------------------------------------------------------------

def _extract_author_line(soup: BeautifulSoup) -> str:
    """Scan first 6 <p> for 'By ...' line, then fall back to meta selectors."""
    paragraphs = soup.find_all("p", limit=10)
    for i, p in enumerate(paragraphs):
        if i > 6:
            break
        text = p.get_text(strip=True)
        if text.lower().startswith("by "):
            return text

    # Fallback meta selectors (same order as AggieArticleParser.swift)
    for selector in [
        ".author-name",
        ".entry-author",
        ".author.vcard a",
        ".byline a",
        ".entry-meta .author",
    ]:
        el = soup.select_one(selector)
        if el and el.get_text(strip=True):
            return el.get_text(strip=True)

    return "The Aggie"


def _parse_author_line(raw: str) -> tuple[str, str | None]:
    """
    Parses 'By AALIYAH ESPAÑOL-RIVAS — campus@theaggie.org' into (name, email).
    """
    cleaned = re.sub(r"(?i)^by\s+", "", raw).strip()

    if "\u2014" in cleaned:  # em dash
        parts = cleaned.split("\u2014", 1)
        name = parts[0].strip()
        email = parts[1].strip() if len(parts) > 1 else None
        return (name or "The Aggie", email)

    return (cleaned or "The Aggie", None)


# --------------------------------------------------------------------------
# MARK: - Category
# --------------------------------------------------------------------------

def _extract_category(soup: BeautifulSoup) -> str:
    el = soup.select_one("a[rel='category tag']")
    if el and el.get_text(strip=True):
        return el.get_text(strip=True)
    el = soup.select_one(".cat-links a")
    if el and el.get_text(strip=True):
        return el.get_text(strip=True)
    return ""


# --------------------------------------------------------------------------
# MARK: - Thumbnail
# --------------------------------------------------------------------------

def _extract_thumbnail(soup: BeautifulSoup) -> str | None:
    for selector in [".post-thumbnail img", "img.wp-post-image", "article img"]:
        el = soup.select_one(selector)
        if el and el.get("src"):
            return el["src"]
    return None


# --------------------------------------------------------------------------
# MARK: - Body Paragraphs
# --------------------------------------------------------------------------

_NOISE_PATTERNS = [
    "follow us on",
    "subscribe to",
    "support the aggie",
    "\u00a9",  # ©
    "written by",
]


def _extract_body_paragraphs(soup: BeautifulSoup) -> list[str]:
    """Extracts cleaned body paragraphs, mirroring AggieArticleParser.swift."""

    # Try WordPress content containers in priority order
    container = None
    for selector in [".entry-content", ".post-content", ".article-content", "article .content"]:
        container = soup.select_one(selector)
        if container:
            break

    # Fallback to full <article> or <body>
    if container is None:
        container = soup.select_one("article") or soup.body
    if container is None:
        return []

    paragraphs = container.find_all("p")
    cleaned = []

    for p in paragraphs:
        text = _extract_text_preserving_bold(p).strip()

        if len(text) <= 20:
            continue
        lower = text.lower()
        if lower.startswith("by "):
            continue
        if any(pat in lower for pat in _NOISE_PATTERNS):
            continue

        cleaned.append(text)

    return cleaned


def _extract_text_preserving_bold(element) -> str:
    """Converts inner HTML of a <p> to plain text, wrapping <strong>/<b> with **markdown**."""
    html = element.decode_contents()  # inner HTML

    # Replace <strong> and <b> tags with markdown bold markers
    html = re.sub(r"<(strong|b)[^>]*>", "**", html, flags=re.IGNORECASE)
    html = re.sub(r"</(strong|b)>", "**", html, flags=re.IGNORECASE)

    # Strip all remaining HTML tags
    html = re.sub(r"<[^>]+>", "", html)

    # Tighten ** markers: "** text **" → "**text**"
    html = re.sub(r"\*\*\s+", "**", html)
    html = re.sub(r"\s+\*\*", "**", html)

    # Decode common HTML entities
    html = (
        html.replace("&amp;", "&")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&quot;", '"')
        .replace("&nbsp;", " ")
        .replace("&#160;", " ")
        .replace("&#8220;", "\u201c")
        .replace("&#8221;", "\u201d")
        .replace("&#8216;", "\u2018")
        .replace("&#8217;", "\u2019")
        .replace("&#8230;", "\u2026")
        .replace("&#38;", "&")
    )

    return html
