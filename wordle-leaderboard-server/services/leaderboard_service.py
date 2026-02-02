#
#  leaderboard_service.py
#  TapInApp - Wordle Leaderboard Server
#
#  Created by Darius Ehsani on 2/2/26.
#
#  MARK: - Leaderboard Service
#  This service handles all leaderboard business logic including:
#  - Username generation (Adjective+Noun format)
#  - Score submission and storage
#  - Leaderboard retrieval and ranking
#
#  Architecture:
#  - Uses in-memory storage for Milestone 0 (will migrate to Firestore later)
#  - Singleton pattern via module-level instance
#  - Scores are organized by puzzle date for daily leaderboards
#
#  Storage Format:
#  - _scores: Dict[str, List[Score]] where key is puzzle_date (YYYY-MM-DD)
#

import random
from typing import List, Optional, Dict
from models import Score, LeaderboardEntry


# ------------------------------------------------------------------------------
# MARK: - Username Generation Data
# ------------------------------------------------------------------------------

# Adjectives for random username generation
ADJECTIVES = [
    "Swift", "Brave", "Clever", "Mighty", "Noble",
    "Bold", "Quick", "Sharp", "Bright", "Keen",
    "Agile", "Fierce", "Lucky", "Calm", "Wise",
    "Golden", "Silver", "Cosmic", "Epic", "Grand",
    "Royal", "Mystic", "Ancient", "Stellar", "Thunder"
]

# Nouns for random username generation
NOUNS = [
    "Falcon", "Otter", "Wolf", "Eagle", "Bear",
    "Tiger", "Lion", "Hawk", "Fox", "Deer",
    "Panda", "Koala", "Shark", "Dragon", "Phoenix",
    "Mustang", "Aggie", "Knight", "Warrior", "Champion",
    "Legend", "Pioneer", "Voyager", "Ranger", "Scout"
]


# ------------------------------------------------------------------------------
# MARK: - LeaderboardService Class
# ------------------------------------------------------------------------------

class LeaderboardService:
    """
    Service class for managing Wordle leaderboard operations.

    This class provides methods for:
    - Generating unique usernames
    - Submitting and storing scores
    - Retrieving ranked leaderboards

    Storage:
    - Currently uses in-memory dictionary (Milestone 0)
    - Will be migrated to Firestore Datastore in future milestones

    Usage:
        service = LeaderboardService()

        # Submit a score
        score = service.submit_score(guesses=4, time_seconds=120, puzzle_date="2026-02-02")

        # Get leaderboard
        entries = service.get_leaderboard("2026-02-02")
    """

    def __init__(self):
        """
        Initializes the LeaderboardService with empty in-memory storage.

        The _scores dictionary maps puzzle dates to lists of Score objects:
        {
            "2026-02-02": [Score(...), Score(...), ...],
            "2026-02-03": [Score(...), ...]
        }
        """
        # In-memory storage: Dict[puzzle_date, List[Score]]
        self._scores: Dict[str, List[Score]] = {}

    # --------------------------------------------------------------------------
    # MARK: - Username Generation
    # --------------------------------------------------------------------------

    def generate_username(self) -> str:
        """
        Generates a random username in Adjective+Noun format.

        Examples: "SwiftFalcon", "BraveOtter", "CleverWolf"

        Returns:
            A randomly generated username string
        """
        adjective = random.choice(ADJECTIVES)
        noun = random.choice(NOUNS)
        return f"{adjective}{noun}"

    # --------------------------------------------------------------------------
    # MARK: - Score Submission
    # --------------------------------------------------------------------------

    def submit_score(
        self,
        guesses: int,
        time_seconds: int,
        puzzle_date: str,
        username: Optional[str] = None
    ) -> Score:
        """
        Submits a new score to the leaderboard.

        Creates a new Score entry with an auto-generated username (if not provided)
        and stores it in the in-memory database.

        Args:
            guesses: Number of guesses taken (1-6)
            time_seconds: Time taken to complete the puzzle in seconds
            puzzle_date: The date of the puzzle (YYYY-MM-DD format)
            username: Optional custom username (auto-generated if not provided)

        Returns:
            The created Score object

        Raises:
            ValueError: If guesses is not between 1 and 6

        Example:
            score = service.submit_score(
                guesses=4,
                time_seconds=120,
                puzzle_date="2026-02-02"
            )
            print(score.username)  # "SwiftFalcon"
        """
        # Validate guesses range
        if not 1 <= guesses <= 6:
            raise ValueError("Guesses must be between 1 and 6")

        # Generate username if not provided
        if username is None:
            username = self.generate_username()

        # Create the score object
        score = Score(
            username=username,
            guesses=guesses,
            time_seconds=time_seconds,
            puzzle_date=puzzle_date
        )

        # Initialize list for this date if it doesn't exist
        if puzzle_date not in self._scores:
            self._scores[puzzle_date] = []

        # Add score to storage
        self._scores[puzzle_date].append(score)

        return score

    # --------------------------------------------------------------------------
    # MARK: - Leaderboard Retrieval
    # --------------------------------------------------------------------------

    def get_leaderboard(self, puzzle_date: str, limit: int = 5) -> List[LeaderboardEntry]:
        """
        Retrieves the top scores for a specific puzzle date.

        Scores are ranked by:
        1. Number of guesses (fewer is better)
        2. Time taken (faster is better, used as tiebreaker)

        Args:
            puzzle_date: The date of the puzzle (YYYY-MM-DD format)
            limit: Maximum number of entries to return (default: 5)

        Returns:
            List of LeaderboardEntry objects, sorted by rank

        Example:
            entries = service.get_leaderboard("2026-02-02")
            for entry in entries:
                print(f"{entry.rank}. {entry.username} - {entry.guesses_display}")
        """
        # Get scores for this date (empty list if none exist)
        scores = self._scores.get(puzzle_date, [])

        # Sort by guesses (ascending), then by time (ascending) as tiebreaker
        sorted_scores = sorted(scores, key=lambda s: (s.guesses, s.time_seconds))

        # Take top N scores
        top_scores = sorted_scores[:limit]

        # Convert to LeaderboardEntry objects with rank and emoji display
        entries = []
        for rank, score in enumerate(top_scores, start=1):
            entry = LeaderboardEntry(
                rank=rank,
                username=score.username,
                guesses=score.guesses,
                guesses_display=self._format_guesses_emoji(score.guesses),
                time_seconds=score.time_seconds
            )
            entries.append(entry)

        return entries

    # --------------------------------------------------------------------------
    # MARK: - Helper Methods
    # --------------------------------------------------------------------------

    def _format_guesses_emoji(self, guesses: int) -> str:
        """
        Converts number of guesses to green block emoji representation.

        Args:
            guesses: Number of guesses (1-6)

        Returns:
            String of green block emojis (e.g., 3 guesses = "🟩🟩🟩")
        """
        return "🟩" * guesses

    def get_all_dates(self) -> List[str]:
        """
        Returns all puzzle dates that have scores.

        Useful for debugging and admin purposes.

        Returns:
            List of puzzle date strings (YYYY-MM-DD format)
        """
        return list(self._scores.keys())

    def clear_scores(self, puzzle_date: Optional[str] = None) -> None:
        """
        Clears scores from storage.

        Args:
            puzzle_date: If provided, only clears scores for that date.
                        If None, clears all scores.

        Note: This is primarily for testing purposes.
        """
        if puzzle_date:
            self._scores.pop(puzzle_date, None)
        else:
            self._scores.clear()


# ------------------------------------------------------------------------------
# MARK: - Module-level Instance
# ------------------------------------------------------------------------------

# Create a singleton instance for use across the application
# This ensures all API endpoints share the same in-memory storage
leaderboard_service = LeaderboardService()
