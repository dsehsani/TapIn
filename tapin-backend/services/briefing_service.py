#
#  briefing_service.py
#  TapIn Backend
#
#  Generates a daily AI news briefing from today's Aggie articles.
#  Exactly 1 Claude API call per day — cached in Firestore.
#
#  Flow:
#    1. Check Firestore for today's cached briefing
#    2. On miss: fetch articles from article_repository (or fresh RSS)
#    3. Send titles + excerpts to Claude
#    4. Parse structured response → summary + bullet points
#    5. Cache in Firestore
#

import logging
from datetime import datetime, timezone
from zoneinfo import ZoneInfo

from repositories.briefing_repository import briefing_repository
from repositories.article_repository import article_repository
from services.aggie_rss_service import fetch_articles
from services.claude_service import claude_service

logger = logging.getLogger(__name__)

PACIFIC = ZoneInfo("America/Los_Angeles")

BRIEFING_SYSTEM_PROMPT = (
    "You are a friendly campus news briefer for TapIn, a UC Davis student app. "
    "Given today's article headlines and excerpts from The California Aggie, write:\n"
    "1. A conversational 2-3 sentence summary of today's top news themes. "
    "Write like you're telling a friend what's happening on campus today. "
    "Keep it under 280 characters.\n"
    "2. Exactly 4-5 bullet points, each starting with a relevant emoji, "
    "each under 80 characters, highlighting the most important individual stories.\n\n"
    "Format your response EXACTLY as:\n"
    "SUMMARY: <your summary>\n"
    "BULLETS:\n"
    "<emoji> <bullet 1>\n"
    "<emoji> <bullet 2>\n"
    "<emoji> <bullet 3>\n"
    "<emoji> <bullet 4>\n"
    "[optional 5th bullet]"
)


def get_daily_briefing() -> dict:
    """
    Returns today's briefing, generating it if not cached.
    Returns: { summary, bullet_points, article_count, generated_at, cached }
    """
    today = datetime.now(tz=PACIFIC).strftime("%Y-%m-%d")

    # Check Firestore cache
    cached = briefing_repository.get_briefing(today)
    if cached:
        logger.info(f"Briefing cache hit for {today}")
        return {
            "summary": cached.get("summary", ""),
            "bullet_points": cached.get("bullet_points", []),
            "article_count": cached.get("article_count", 0),
            "generated_at": cached.get("generated_at", ""),
            "cached": True,
        }

    # Cache miss — generate new briefing
    logger.info(f"Briefing cache miss for {today} — generating")
    return _generate_briefing(today)


def _generate_briefing(date_str: str) -> dict:
    """Fetches articles, calls Claude, caches and returns the briefing."""

    # Step 1: Get articles (stale-check → fresh RSS → stale cache fallback)
    if article_repository.is_stale("all"):
        articles = fetch_articles("all")
        if articles:
            article_repository.save_articles("all", articles)
        else:
            # RSS failed — fall back to stale cache rather than nothing
            articles = article_repository.get_articles("all")
    else:
        articles = article_repository.get_articles("all")

    if not articles:
        articles = fetch_articles("all")

    if not articles:
        return {
            "summary": "No articles available yet today. Check back soon!",
            "bullet_points": [],
            "article_count": 0,
            "generated_at": datetime.now(tz=timezone.utc).isoformat(),
            "cached": False,
        }

    # Step 2: Build prompt from top 12 articles
    top_articles = articles[:12]
    article_text = "\n\n".join(
        f"HEADLINE: {a.get('title', '')}\nEXCERPT: {a.get('excerpt', '')[:200]}"
        for a in top_articles
    )

    # Step 3: Call Claude API
    try:
        client = claude_service._get_client()
        message = client.messages.create(
            model="claude-sonnet-4-5-20250929",
            max_tokens=400,
            system=BRIEFING_SYSTEM_PROMPT,
            messages=[{
                "role": "user",
                "content": f"Here are today's articles from The California Aggie:\n\n{article_text}"
            }]
        )
        raw = message.content[0].text.strip()
    except Exception as e:
        logger.error(f"Claude API call failed for briefing: {e}")
        return {
            "summary": "AI briefing is temporarily unavailable.",
            "bullet_points": [],
            "article_count": len(top_articles),
            "generated_at": datetime.now(tz=timezone.utc).isoformat(),
            "cached": False,
        }

    # Step 4: Parse the response
    summary, bullets = _parse_briefing_response(raw)

    # Step 5: Cache in Firestore
    briefing = {
        "summary": summary,
        "bullet_points": bullets,
        "article_count": len(top_articles),
        "source_titles": [a.get("title", "") for a in top_articles],
    }
    briefing_repository.save_briefing(date_str, briefing)

    return {
        "summary": summary,
        "bullet_points": bullets,
        "article_count": len(top_articles),
        "generated_at": datetime.now(tz=timezone.utc).isoformat(),
        "cached": False,
    }


def _parse_briefing_response(raw: str) -> tuple[str, list[str]]:
    """Parses Claude's formatted response into (summary, bullet_points)."""
    summary = ""
    bullets = []

    lines = raw.strip().splitlines()
    in_bullets = False

    for line in lines:
        stripped = line.strip()
        if stripped.upper().startswith("SUMMARY:"):
            summary = stripped[len("SUMMARY:"):].strip()
        elif stripped.upper().startswith("BULLETS:"):
            in_bullets = True
        elif in_bullets and stripped:
            bullets.append(stripped)

    # Fallback if parsing fails — use the entire response as the summary
    if not summary and not bullets:
        summary = raw[:280]

    return summary, bullets[:5]
