#
#  briefing_service.py
#  TapIn Backend
#
#  Generates a personalized daily briefing from articles + campus events.
#  Returns structured items with images and links for story-card display.
#  Cached in Firestore, scoped by user interests.
#

import logging
from datetime import datetime, timezone, timedelta
from zoneinfo import ZoneInfo

from repositories.briefing_repository import briefing_repository
from repositories.article_repository import article_repository
from repositories.article_content_repository import article_content_repository
from repositories.event_repository import event_repository
from services.aggie_rss_service import fetch_articles
from services.claude_service import claude_service

logger = logging.getLogger(__name__)

PACIFIC = ZoneInfo("America/Los_Angeles")

BRIEFING_SYSTEM_PROMPT = (
    "You are a campus briefing bot for TapIn, a UC Davis student app. "
    "You receive numbered articles [A1], [A2]... and events [E1], [E2]... "
    "Your job: pick the most exciting, relevant items for this user.\n\n"

    "PRODUCE:\n"
    "1. HERO — One short, exciting sentence (under 40 chars) about the SINGLE most "
    "appealing thing for this user. Be specific — reference the actual event or story.\n"
    "   Examples: \"Free Tacos at the MU Today!\", \"Aggies vs UCSB Tonight at 7!\", "
    "\"UC Davis Makes Medical History\"\n\n"

    "2. PICKS — 2 to 5 items from the numbered list. For each, give:\n"
    "   - The item ID (e.g. A1 or E3)\n"
    "   - One emoji\n"
    "   - A short catchy subtitle (under 45 chars) — this overlays the image\n\n"

    "RULES:\n"
    "- ONLY pick items matching the user's interests. Quality over quantity.\n"
    "- Events with free food, live music, or games are always high priority.\n"
    "- The HERO should reference the most enticing picked item.\n"
    "- If fewer than 2 items match, return only what matches.\n"
    "- Do NOT pad with irrelevant filler.\n"
    "- If no interests provided, pick the 3-4 most exciting things overall.\n\n"

    "Format EXACTLY as:\n"
    "HERO: <hero sentence>\n"
    "PICKS:\n"
    "<id> | <emoji> | <subtitle>\n"
    "<id> | <emoji> | <subtitle>\n"
    "[up to 5 lines]"
)


def _cache_key(date_str: str, interests: list[str]) -> str:
    """Returns a Firestore document key scoped by date and interests."""
    if not interests:
        return date_str
    suffix = ",".join(sorted(i.lower() for i in interests))
    return f"{date_str}_{hash(suffix)}"


def get_daily_briefing(interests: list[str] | None = None, force: bool = False) -> dict:
    """
    Returns today's briefing, generating it if not cached.
    When interests are provided, the cache and prompt are scoped per interest set.
    Pass force=True to bypass cache and regenerate.
    """
    interests = interests or []
    today = datetime.now(tz=PACIFIC).strftime("%Y-%m-%d")
    cache_key = _cache_key(today, interests)

    # Check Firestore cache (skip if forcing)
    if not force:
        cached = briefing_repository.get_briefing(cache_key)
        if cached:
            logger.info(f"Briefing cache hit for {cache_key}")
            return {
                "summary": "",
                "bullet_points": cached.get("bullet_points", []),
                "hero_title": cached.get("hero_title"),
                "items": cached.get("items", []),
                "article_count": cached.get("article_count", 0),
                "generated_at": cached.get("generated_at", ""),
                "cached": True,
            }

    # Cache miss (or forced) — generate new briefing
    logger.info(f"Briefing {'force refresh' if force else 'cache miss'} for {cache_key} — generating")
    return _generate_briefing(cache_key, interests)


def _generate_briefing(cache_key: str, interests: list[str] | None = None) -> dict:
    """Fetches articles + events, calls Claude, caches and returns the briefing."""
    interests = interests or []

    # Step 1a: Get articles
    if article_repository.is_stale("all"):
        articles = fetch_articles("all")
        if articles:
            article_repository.save_articles("all", articles)
        else:
            articles = article_repository.get_articles("all")
    else:
        articles = article_repository.get_articles("all")

    if not articles:
        articles = fetch_articles("all")
    articles = articles or []

    # Step 1b: Get campus events from Firestore (future only)
    events = []
    try:
        all_events = event_repository.get_all_events()
        now_iso = datetime.now(tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        events = [e for e in all_events if (e.get("startDate") or "") >= now_iso]
    except Exception as e:
        logger.warning(f"Failed to fetch events for briefing: {e}")

    # Step 1c: Filter articles to recent ones only (last 7 days)
    cutoff = (datetime.now(tz=timezone.utc) - timedelta(days=7)).strftime("%Y-%m-%dT%H:%M:%SZ")
    articles = [a for a in articles if (a.get("publishDate") or "") >= cutoff]

    if not articles and not events:
        return {
            "summary": "",
            "bullet_points": [],
            "hero_title": None,
            "items": [],
            "article_count": 0,
            "generated_at": datetime.now(tz=timezone.utc).isoformat(),
            "cached": False,
        }

    # Step 2: Build numbered item lists and lookup maps
    top_articles = articles[:10]
    top_events = events[:10]
    item_lookup = {}

    article_lines = []
    for i, a in enumerate(top_articles):
        key = f"A{i+1}"
        article_lines.append(
            f"[{key}] {a.get('title', '')} — {a.get('excerpt', '')[:150]}"
        )
        item_lookup[key] = {
            "type": "article",
            "title": a.get("title", ""),
            "imageURL": a.get("imageURL") or a.get("image_url") or None,
            "linkURL": a.get("articleURL") or a.get("article_url") or a.get("link"),
        }
        # Treat empty strings as None
        if not item_lookup[key]["imageURL"]:
            item_lookup[key]["imageURL"] = None

    event_lines = []
    for i, e in enumerate(top_events):
        key = f"E{i+1}"
        desc = (e.get("description") or e.get("aiSummary") or "")[:120]
        event_lines.append(
            f"[{key}] {e.get('title', '')} — {e.get('location', 'TBD')} — "
            f"{(e.get('startDate') or '')[:16]} — {desc}"
        )
        item_lookup[key] = {
            "type": "event",
            "title": e.get("title", ""),
            "imageURL": e.get("imageURL") or e.get("image_url"),
            "linkURL": e.get("eventURL") or e.get("event_url"),
        }

    total_items = len(top_articles) + len(top_events)

    # Build user message
    user_content = ""
    if article_lines:
        user_content += "TODAY'S ARTICLES:\n" + "\n".join(article_lines) + "\n\n"
    if event_lines:
        user_content += "UPCOMING CAMPUS EVENTS:\n" + "\n".join(event_lines) + "\n\n"
    if interests:
        user_content += f"User interests: {', '.join(interests)}"
    else:
        user_content += "No user interests specified — pick the most exciting things overall."

    # Step 3: Call Claude API
    try:
        client = claude_service._get_client()
        message = client.messages.create(
            model="claude-sonnet-4-5-20250929",
            max_tokens=300,
            system=BRIEFING_SYSTEM_PROMPT,
            messages=[{
                "role": "user",
                "content": user_content,
            }]
        )
        raw = message.content[0].text.strip()
    except Exception as e:
        logger.error(f"Claude API call failed for briefing: {e}")
        return {
            "summary": "",
            "bullet_points": [],
            "hero_title": None,
            "items": [],
            "article_count": total_items,
            "generated_at": datetime.now(tz=timezone.utc).isoformat(),
            "cached": False,
        }

    # Step 4: Parse response and enrich with item data
    hero_title, picks = _parse_briefing_response(raw)

    items = []
    bullet_points = []
    for item_id, emoji, subtitle in picks:
        source = item_lookup.get(item_id.upper())
        if source:
            image_url = source.get("imageURL")

            # For articles without an image, try the scraped content cache
            if not image_url and source["type"] == "article" and source.get("linkURL"):
                image_url = _lookup_thumbnail(source["linkURL"])

            # For any item still without an image, assign a themed fallback
            if not image_url:
                image_url = _fallback_image(source["title"], subtitle)

            items.append({
                "type": source["type"],
                "title": source["title"],
                "subtitle": subtitle,
                "emoji": emoji,
                "imageURL": image_url,
                "linkURL": source.get("linkURL"),
            })
        # Also build legacy bullet_points for backward compat
        bullet_points.append(f"{emoji} {subtitle}")

    # Step 4b: Reorder so the hero-matching item is first
    if hero_title and len(items) > 1:
        hero_lower = hero_title.lower()
        best_idx = 0
        best_score = 0
        for i, item in enumerate(items):
            title_words = item["title"].lower().split()
            score = sum(1 for w in title_words if w in hero_lower)
            sub_words = item["subtitle"].lower().split()
            score += sum(1 for w in sub_words if w in hero_lower)
            if score > best_score:
                best_score = score
                best_idx = i
        if best_idx != 0 and best_score > 0:
            items.insert(0, items.pop(best_idx))

    # Step 5: Cache in Firestore
    briefing = {
        "summary": "",
        "bullet_points": bullet_points,
        "hero_title": hero_title,
        "items": items,
        "article_count": total_items,
    }
    briefing_repository.save_briefing(cache_key, briefing)

    return {
        "summary": "",
        "bullet_points": bullet_points,
        "hero_title": hero_title,
        "items": items,
        "article_count": total_items,
        "generated_at": datetime.now(tz=timezone.utc).isoformat(),
        "cached": False,
    }


# Themed fallback images from Unsplash (free to use).
# Each category maps keywords → a curated campus/theme photo.
_FALLBACK_IMAGES = {
    "sports": "https://images.unsplash.com/photo-1461896836934-bd45ba8fcfdb?w=800&h=400&fit=crop&q=80",
    "food": "https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800&h=400&fit=crop&q=80",
    "music": "https://images.unsplash.com/photo-1501386761578-0a55c12e6fa5?w=800&h=400&fit=crop&q=80",
    "art": "https://images.unsplash.com/photo-1547891654-e66ed7ebb968?w=800&h=400&fit=crop&q=80",
    "study": "https://images.unsplash.com/photo-1481627834876-b7833e8f5570?w=800&h=400&fit=crop&q=80",
    "career": "https://images.unsplash.com/photo-1521737711867-e3b97375f902?w=800&h=400&fit=crop&q=80",
    "social": "https://images.unsplash.com/photo-1529156069898-49953e39b3ac?w=800&h=400&fit=crop&q=80",
    "science": "https://images.unsplash.com/photo-1532094349884-543bc11b234d?w=800&h=400&fit=crop&q=80",
    "health": "https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=800&h=400&fit=crop&q=80",
    "default": "https://images.unsplash.com/photo-1562774053-701939374585?w=800&h=400&fit=crop&q=80",
}

_FALLBACK_KEYWORDS = {
    "sports": ["basketball", "football", "soccer", "baseball", "lacrosse", "tennis",
               "volleyball", "track", "swim", "game", "match", "tournament", "athlete",
               "aggies", "aggie", "ucsb", "rivalry", "playoff"],
    "food": ["food", "taco", "pizza", "coffee", "cafe", "dining", "lunch", "dinner",
             "snack", "brunch", "free food", "potluck", "cookout", "bake"],
    "music": ["music", "concert", "band", "jazz", "dj", "open mic", "sing",
              "guitar", "piano", "orchestra", "symphony", "festival"],
    "art": ["art", "gallery", "exhibit", "theater", "theatre", "film", "movie",
            "dance", "fashion", "design", "photography", "paint", "creative"],
    "study": ["study", "library", "exam", "tutor", "workshop", "seminar",
              "lecture", "academic", "research", "lab"],
    "career": ["career", "job", "intern", "hiring", "resume", "interview",
               "fair", "recruit", "profession", "networking"],
    "social": ["party", "mixer", "social", "hangout", "meet", "club",
               "organization", "welcome", "orientation", "community"],
    "science": ["science", "tech", "engineering", "stem", "computer", "robot",
                "ai", "data", "hack", "code", "bio", "chem", "physics"],
    "health": ["health", "wellness", "yoga", "meditation", "mental", "fitness",
               "gym", "run", "walk", "therapy", "counseling"],
}


def _fallback_image(title: str, subtitle: str) -> str:
    """Returns a themed stock photo URL based on event title/subtitle keywords."""
    text = f"{title} {subtitle}".lower()
    for category, keywords in _FALLBACK_KEYWORDS.items():
        if any(kw in text for kw in keywords):
            return _FALLBACK_IMAGES[category]
    return _FALLBACK_IMAGES["default"]


def _lookup_thumbnail(article_url: str) -> str | None:
    """Checks the article content cache for a thumbnailURL."""
    try:
        cached = article_content_repository.get_content(article_url)
        if cached:
            thumb = cached.get("thumbnailURL") or cached.get("thumbnail_url")
            if thumb:
                return thumb
    except Exception as e:
        logger.debug(f"Thumbnail lookup failed for {article_url}: {e}")
    return None


def _parse_briefing_response(raw: str) -> tuple[str | None, list[tuple[str, str, str]]]:
    """
    Parses Claude's response into (hero_title, picks).
    Each pick is (item_id, emoji, subtitle).
    """
    hero_title = None
    picks = []

    lines = raw.strip().splitlines()
    in_picks = False

    for line in lines:
        stripped = line.strip()
        if stripped.upper().startswith("HERO:"):
            hero_title = stripped[len("HERO:"):].strip()
        elif stripped.upper().startswith("PICKS:"):
            in_picks = True
        elif in_picks and "|" in stripped:
            parts = [p.strip() for p in stripped.split("|", 2)]
            if len(parts) == 3:
                item_id, emoji, subtitle = parts
                picks.append((item_id.strip(), emoji.strip(), subtitle.strip()))

    return hero_title, picks[:5]
