#
#  claude_service.py
#  TapInApp - Backend Server
#
#  Created by Darius Ehsani on 2/12/26.
#
#  MARK: - Claude API Proxy Service
#  Handles communication with the Anthropic Claude API.
#  The API key is loaded from environment variables — NEVER hardcoded.
#
#  Usage:
#    claude_service.summarize_event("long event description text...")
#

import os
import time
import hashlib
import anthropic


# ------------------------------------------------------------------------------
# MARK: - Rate Limiter
# ------------------------------------------------------------------------------

class RateLimiter:
    """
    Simple in-memory rate limiter using a sliding window.
    Limits requests per IP address to prevent API abuse.
    """

    def __init__(self, max_requests: int = 30, window_seconds: int = 3600):
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self._requests: dict[str, list[float]] = {}

    def is_allowed(self, identifier: str) -> bool:
        """Check if the identifier (IP address) is within rate limits."""
        now = time.time()
        window_start = now - self.window_seconds

        if identifier not in self._requests:
            self._requests[identifier] = []

        # Remove expired timestamps
        self._requests[identifier] = [
            t for t in self._requests[identifier] if t > window_start
        ]

        if len(self._requests[identifier]) >= self.max_requests:
            return False

        self._requests[identifier].append(now)
        return True

    def remaining(self, identifier: str) -> int:
        """Return how many requests remain for this identifier."""
        now = time.time()
        window_start = now - self.window_seconds

        if identifier not in self._requests:
            return self.max_requests

        active = [t for t in self._requests[identifier] if t > window_start]
        return max(0, self.max_requests - len(active))


# ------------------------------------------------------------------------------
# MARK: - Server-Side Cache
# ------------------------------------------------------------------------------

class SummaryCache:
    """
    Simple in-memory cache keyed by description hash.
    Prevents duplicate API calls for the same event description.
    """

    def __init__(self, max_size: int = 500):
        self.max_size = max_size
        self._cache: dict[str, str] = {}

    @staticmethod
    def _hash(text: str) -> str:
        return hashlib.sha256(text.encode("utf-8")).hexdigest()

    def get(self, description: str) -> str | None:
        return self._cache.get(self._hash(description))

    def set(self, description: str, summary: str) -> None:
        if len(self._cache) >= self.max_size:
            # Evict oldest entry (first inserted)
            oldest_key = next(iter(self._cache))
            del self._cache[oldest_key]
        self._cache[self._hash(description)] = summary


# ------------------------------------------------------------------------------
# MARK: - Claude Service
# ------------------------------------------------------------------------------

class ClaudeService:
    """
    Proxy service for the Anthropic Claude API.
    Manages the API key, rate limiting, caching, and prompt construction.
    """

    # System prompt for event summarization
    SUMMARIZE_SYSTEM_PROMPT = (
        "You are a concise event summarizer for a UC Davis campus app. "
        "Given an event description, respond with ONLY a single short sentence. "
        "STRICT LIMIT: maximum 80 characters total. "
        "No quotation marks. No bullet points. No line breaks. "
        "Friendly tone for college students. Focus on what the event is."
    )

    def __init__(self):
        self.api_key = os.environ.get("CLAUDE_API_KEY")
        self.rate_limiter = RateLimiter(max_requests=30, window_seconds=3600)
        self.cache = SummaryCache(max_size=500)

    def _get_client(self) -> anthropic.Anthropic:
        """Create an Anthropic client. Raises if API key is missing."""
        if not self.api_key:
            raise ValueError(
                "CLAUDE_API_KEY environment variable is not set. "
                "Set it in your .env file or deployment config."
            )
        return anthropic.Anthropic(api_key=self.api_key)

    def summarize_event(self, description: str, client_ip: str = "unknown") -> dict:
        """
        Summarize an event description using Claude.

        Args:
            description: The full event description text.
            client_ip: The requesting client's IP (for rate limiting).

        Returns:
            dict with "summary" key on success,
            or "error" key on failure.
        """
        # --- Rate limiting ---
        if not self.rate_limiter.is_allowed(client_ip):
            remaining = self.rate_limiter.remaining(client_ip)
            return {
                "error": "Rate limit exceeded. Try again later.",
                "remaining": remaining,
                "status_code": 429
            }

        # --- Input validation ---
        if not description or not description.strip():
            return {"error": "Description is empty.", "status_code": 400}

        if len(description) > 5000:
            return {"error": "Description too long (max 5000 chars).", "status_code": 400}

        # --- Cache check ---
        cached = self.cache.get(description)
        if cached:
            return {
                "summary": cached,
                "cached": True,
                "remaining": self.rate_limiter.remaining(client_ip)
            }

        # --- Call Claude API ---
        try:
            client = self._get_client()

            message = client.messages.create(
                model="claude-sonnet-4-5-20250929",
                max_tokens=60,
                system=self.SUMMARIZE_SYSTEM_PROMPT,
                messages=[
                    {
                        "role": "user",
                        "content": f"Summarize this campus event:\n\n{description}"
                    }
                ]
            )

            summary = message.content[0].text.strip()

            # Cache the result
            self.cache.set(description, summary)

            return {
                "summary": summary,
                "cached": False,
                "remaining": self.rate_limiter.remaining(client_ip)
            }

        except anthropic.AuthenticationError:
            return {
                "error": "Invalid API key. Check CLAUDE_API_KEY.",
                "status_code": 401
            }
        except anthropic.RateLimitError:
            return {
                "error": "Anthropic rate limit reached. Try again later.",
                "status_code": 429
            }
        except Exception as e:
            return {
                "error": f"Failed to generate summary: {str(e)}",
                "status_code": 500
            }


    def generate_bullet_points(self, title: str, description: str) -> list[str]:
        """
        Generates 3-5 emoji bullet points for an event's About section.
        Called internally by the event processor — no rate limiting applied.

        Args:
            title: The event title.
            description: The full event description.

        Returns:
            List of emoji bullet point strings, or empty list on failure.
        """
        if not description or not description.strip():
            return []

        cache_key = f"{title}\n{description}"
        cached = self._bullet_cache.get(cache_key)
        if cached:
            return cached

        system_prompt = (
            "You are a concise event summarizer for a UC Davis campus app. "
            "Extract the 3 to 5 most important facts from the event details. "
            "Return ONLY emoji bullet points, one per line, with no extra text or markdown. "
            "Each line must start with a relevant emoji followed by a space, "
            "then a brief phrase under 12 words. "
            "Pick emojis that match the content "
            "(📍 location, 💰 cost, 🎓 academic, 🍕 food, 🎤 speaker, 🕐 time, 🔗 link, etc.)."
        )

        try:
            client = self._get_client()
            message = client.messages.create(
                model="claude-sonnet-4-5-20250929",
                max_tokens=200,
                system=system_prompt,
                messages=[
                    {
                        "role": "user",
                        "content": f"Event: {title}\n\n{description}"
                    }
                ]
            )

            raw = message.content[0].text.strip()
            lines = [l.strip() for l in raw.splitlines() if l.strip()]
            self._bullet_cache.set(cache_key, lines)
            return lines

        except Exception:
            return []

    def extract_location_from_description(self, title: str, description: str) -> str | None:
        """
        Scans an event description for a venue or location mention.
        Called internally by the event processor when location == "TBD".

        Args:
            title: The event title (provides helpful context).
            description: The full event description text.

        Returns:
            A short location string (e.g. "CoHo", "Wellman Hall 26", "Zoom"),
            or None if no location is found in the text.
        """
        if not description or not description.strip():
            return None

        cache_key = f"loc_{title}\n{description}"
        cached = self._location_cache.get(cache_key)
        if cached is not None:
            return cached if cached != "__NONE__" else None

        system_prompt = (
            "You are a location extractor for a UC Davis campus events app. "
            "Your only job is to find a venue or location name mentioned in the event text. "
            "Return ONLY the location name — nothing else. No sentences, no punctuation. "
            "If the event is online, return 'Zoom' or the platform name. "
            "If no specific location is mentioned, return exactly: NONE"
        )

        user_prompt = (
            f"Event: {title}\n\n"
            f"{description}\n\n"
            "What is the location or venue for this event? "
            "Reply with ONLY the location name, or NONE if not mentioned."
        )

        try:
            client = self._get_client()
            message = client.messages.create(
                model="claude-haiku-4-5-20251001",
                max_tokens=30,
                system=system_prompt,
                messages=[{"role": "user", "content": user_prompt}]
            )

            raw = message.content[0].text.strip()

            if not raw or raw.upper() == "NONE" or len(raw) > 80:
                self._location_cache.set(cache_key, "__NONE__")
                return None

            self._location_cache.set(cache_key, raw)
            return raw

        except Exception:
            return None

    def search_club_location(self, organizer_name: str, club_acronym: str | None = None) -> dict | None:
        """
        Uses Claude + web search to find where a club typically meets.
        Only called when iCal location == "TBD" AND description scan found nothing.

        Returns:
            dict with keys: { "location": str, "source": str } on success,
            or None if nothing credible is found.
        """
        if not organizer_name or not organizer_name.strip():
            return None

        cache_key = f"webloc_{organizer_name}_{club_acronym or ''}"
        cached = self._web_location_cache.get(cache_key)
        if cached is not None:
            import json
            try:
                return json.loads(cached) if cached != "__NONE__" else None
            except Exception:
                return None

        system_prompt = (
            "You are a research assistant helping a UC Davis campus events app. "
            "Use your web search tool to find where a UC Davis student club typically holds its meetings or events. "
            "Look at their ASUCD page, club website, Linktree, or Instagram bio. "
            "Return a JSON object with exactly two keys: "
            '  "location": a short venue name (e.g. "Wellman Hall", "CoHo", "Zoom"), '
            '  "source": a short label for where you found it (e.g. "ASUCD page", "club website", "Linktree"). '
            'If you cannot find a credible, specific location, return exactly: {"location": null, "source": null}. '
            "Never guess or hallucinate. Only return a location you actually found in a source."
        )

        try:
            client = self._get_client()

            message = client.messages.create(
                model="claude-sonnet-4-5-20250929",
                max_tokens=120,
                system=system_prompt,
                tools=[{"type": "web_search_20250305", "name": "web_search", "max_uses": 2}],
                messages=[
                    {
                        "role": "user",
                        "content": f"Find where this UC Davis club usually meets: {organizer_name}"
                                   + (f" (acronym: {club_acronym})" if club_acronym else "")
                    }
                ]
            )

            # Extract the final text response from the message
            raw = ""
            for block in message.content:
                if hasattr(block, "text"):
                    raw = block.text.strip()
                    break

            if not raw:
                self._web_location_cache.set(cache_key, "__NONE__")
                return None

            import json, re
            json_match = re.search(r'\{.*?\}', raw, re.DOTALL)
            if not json_match:
                self._web_location_cache.set(cache_key, "__NONE__")
                return None

            result = json.loads(json_match.group())
            location = result.get("location")
            source = result.get("source")

            if not location or location == "null":
                self._web_location_cache.set(cache_key, "__NONE__")
                return None

            if len(location) > 80:
                self._web_location_cache.set(cache_key, "__NONE__")
                return None

            output = {"location": location, "source": source or "web"}
            self._web_location_cache.set(cache_key, json.dumps(output))
            return output

        except Exception:
            return None

    def summarize_event_internal(self, description: str) -> str | None:
        """
        Summarizes an event description without rate limiting.
        Used internally by the event processor.
        """
        if not description or not description.strip():
            return None

        cached = self.cache.get(description)
        if cached:
            return cached

        try:
            client = self._get_client()
            message = client.messages.create(
                model="claude-sonnet-4-5-20250929",
                max_tokens=60,
                system=self.SUMMARIZE_SYSTEM_PROMPT,
                messages=[
                    {
                        "role": "user",
                        "content": f"Summarize this campus event:\n\n{description}"
                    }
                ]
            )
            summary = message.content[0].text.strip()
            self.cache.set(description, summary)
            return summary
        except Exception:
            return None


# ------------------------------------------------------------------------------
# MARK: - Location Confidence Scoring
# ------------------------------------------------------------------------------

# Known UC Davis buildings — used by compute_location_confidence to boost scores
# when the AI-extracted location matches a real campus building.
KNOWN_UC_DAVIS_BUILDINGS = [
    "memorial union", "arc pavilion", "arc",
    "shields library", "wellman hall", "hutchison hall",
    "olson hall", "mondavi center", "freeborn hall",
    "young hall", "kemper hall", "cruess hall",
    "sciences lecture hall", "giedt hall", "haring hall",
    "hunt hall", "walker hall", "rock hall",
    "student community center", "coho", "coffee house",
    "the silo", "the quad",
    "activities and recreation center",
    "international center", "genome center",
    "conference center", "alumni center",
    "putah creek lodge", "walter a. buehler",
    "surge", "everson hall", "hart hall",
    "plant and environmental sciences",
    "social sciences", "sprocket",
]

# Social media sources get a lower confidence than official sources
_SOCIAL_MEDIA_SOURCES = {"instagram", "twitter", "x", "facebook", "reddit", "tiktok"}


def compute_location_confidence(event: dict) -> tuple[int, str]:
    """
    Pure-Python heuristic that scores how trustworthy an event's location is.
    Zero API cost — uses only the fields already on the event dict.

    Returns:
        (score 0-100, human-readable reason string)
    """
    location = event.get("location", "TBD")
    has_real_location = location not in ("TBD", "", None)
    description = (event.get("description") or "").lower()
    ai_location = event.get("aiLocation")
    web_location = event.get("webLocation")
    web_source = event.get("webLocationSource") or "web"

    # ── iCal confirmed location ──
    if has_real_location:
        loc_lower = location.lower()
        # Check if the iCal location is also mentioned in the description
        if loc_lower in description or any(
            word in description for word in loc_lower.split() if len(word) > 3
        ):
            return 100, "Confirmed on event page"
        return 95, "Listed by event organizer"

    # ── AI extracted from description ──
    if ai_location:
        ai_lower = ai_location.lower()
        # Online event detection
        online_keywords = ["zoom", "online", "virtual", "teams", "discord", "webex", "google meet"]
        if any(kw in ai_lower for kw in online_keywords):
            return 60, "Online event detected"
        # Known UC Davis building
        if any(building in ai_lower for building in KNOWN_UC_DAVIS_BUILDINGS):
            return 85, "Found specific building in description"
        return 75, "Location mentioned in description"

    # ── Web search result ──
    if web_location:
        source_lower = web_source.lower()
        # Official sources (ASUCD, club website, etc.)
        if any(kw in source_lower for kw in ("asucd", "club website", "official", ".edu")):
            return 55, f"Found on {web_source}"
        # Social media
        if any(kw in source_lower for kw in _SOCIAL_MEDIA_SOURCES):
            return 30, f"Found on {web_source} — may be outdated"
        return 45, f"Found via web search"

    # ── No location at all ──
    return 0, "No location information available"


# Singleton instance
claude_service = ClaudeService()
claude_service._bullet_cache = SummaryCache(max_size=500)
claude_service._location_cache = SummaryCache(max_size=500)
claude_service._web_location_cache = SummaryCache(max_size=500)
