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


# Singleton instance
claude_service = ClaudeService()
