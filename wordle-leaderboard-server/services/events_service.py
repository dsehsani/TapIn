#
#  events_service.py
#  TapInApp - Events Backend
#
#  Created by Claude for Darius Ehsani on 3/1/26.
#
#  MARK: - Events Service
#  Orchestration layer with in-memory caching, deduplication, and sorting.
#

import time
from datetime import datetime, timezone

from .ical_fetcher import fetch_and_parse_all_feeds


# ------------------------------------------------------------------------------
# MARK: - Cache Configuration
# ------------------------------------------------------------------------------

CACHE_TTL_SECONDS = 300  # 5 minutes


# ------------------------------------------------------------------------------
# MARK: - Events Service
# ------------------------------------------------------------------------------

class EventsService:
    """
    Manages event fetching with an in-memory cache.

    Features:
    - 5-minute TTL cache to avoid hammering iCal feeds
    - Deduplication by event title + start date
    - Sorted by start date (soonest first)
    """

    def __init__(self):
        self._cache: list[dict] = []
        self._cache_timestamp: float = 0

    def _is_cache_valid(self) -> bool:
        """Check if the cached data is still fresh."""
        if not self._cache:
            return False
        return (time.time() - self._cache_timestamp) < CACHE_TTL_SECONDS

    def get_events(self, force_refresh: bool = False) -> list[dict]:
        """
        Get all events, using cache if available.

        Args:
            force_refresh: If True, bypass cache and re-fetch from feeds.

        Returns:
            List of event dicts sorted by start date.
        """
        if not force_refresh and self._is_cache_valid():
            return self._cache

        # Fetch fresh data
        raw_events = fetch_and_parse_all_feeds()

        # Deduplicate by title + startDate
        events = self._deduplicate(raw_events)

        # Sort by start date (soonest first)
        events.sort(key=lambda e: e.get("startDate", ""))

        # Filter out past events (older than today)
        now_iso = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        events = [e for e in events if e.get("startDate", "") >= now_iso]

        # Update cache
        self._cache = events
        self._cache_timestamp = time.time()

        print(f"[EventsService] Cached {len(events)} events")
        return events

    def _deduplicate(self, events: list[dict]) -> list[dict]:
        """
        Remove duplicate events based on title + startDate.
        Keeps the first occurrence.
        """
        seen = set()
        unique = []

        for event in events:
            key = (event.get("title", "").lower(), event.get("startDate", ""))
            if key not in seen:
                seen.add(key)
                unique.append(event)

        removed = len(events) - len(unique)
        if removed > 0:
            print(f"[EventsService] Removed {removed} duplicate events")

        return unique


# Singleton instance
events_service = EventsService()
