#
#  unified_leaderboard_service.py
#  TapInApp - Backend Server
#
#  MARK: - Unified Leaderboard Service
#  Service for handling leaderboard operations across all game types.
#  Supports Wordle, Echo, Crossword, and Trivia.
#
#  Architecture:
#  - Uses in-memory storage for MVP (will migrate to Firestore later)
#  - Singleton pattern via module-level instance
#  - Scores are organized by (game_type, date) for daily leaderboards
#

import random
from typing import List, Optional, Dict, Tuple
from models import GameScore, UnifiedLeaderboardEntry, VALID_GAME_TYPES


# ------------------------------------------------------------------------------
# MARK: - Username Generation Data
# ------------------------------------------------------------------------------

ADJECTIVES = [
    "Swift", "Brave", "Clever", "Mighty", "Noble",
    "Bold", "Quick", "Sharp", "Bright", "Keen",
    "Agile", "Fierce", "Lucky", "Calm", "Wise",
    "Golden", "Silver", "Cosmic", "Epic", "Grand"
]

NOUNS = [
    "Falcon", "Tiger", "Phoenix", "Eagle", "Wolf",
    "Lion", "Hawk", "Fox", "Bear", "Deer",
    "Dragon", "Panda", "Shark", "Mustang", "Aggie",
    "Knight", "Ranger", "Voyager", "Pioneer", "Champion"
]


# ------------------------------------------------------------------------------
# MARK: - UnifiedLeaderboardService Class
# ------------------------------------------------------------------------------

class UnifiedLeaderboardService:
    """
    Service for managing unified leaderboard operations across all games.
    """

    def __init__(self):
        # In-memory storage: Dict[(game_type, date), List[GameScore]]
        self._scores: Dict[Tuple[str, str], List[GameScore]] = {}

    def generate_username(self) -> str:
        """Generates a random username in Adjective+Noun format."""
        adjective = random.choice(ADJECTIVES)
        noun = random.choice(NOUNS)
        return f"{adjective}{noun}"

    def submit_score(
        self,
        game_type: str,
        score: int,
        date: str,
        username: Optional[str] = None,
        metadata: Optional[Dict] = None
    ) -> GameScore:
        """
        Submits a new score for any game type.

        Args:
            game_type: Type of game (wordle, echo, crossword, trivia)
            score: Computed score value
            date: Date in YYYY-MM-DD format
            username: Optional username (auto-generated if not provided)
            metadata: Game-specific metadata

        Returns:
            The created GameScore object

        Raises:
            ValueError: If game_type is invalid
        """
        if game_type not in VALID_GAME_TYPES:
            raise ValueError(f"Invalid game_type. Must be one of: {VALID_GAME_TYPES}")

        if username is None:
            username = self.generate_username()

        game_score = GameScore(
            game_type=game_type,
            username=username,
            score=score,
            date=date,
            metadata=metadata or {}
        )

        key = (game_type, date)
        if key not in self._scores:
            self._scores[key] = []

        self._scores[key].append(game_score)
        return game_score

    def get_leaderboard(
        self,
        game_type: str,
        date: str,
        limit: int = 5
    ) -> List[UnifiedLeaderboardEntry]:
        """
        Gets the leaderboard for a specific game and date.

        Args:
            game_type: Type of game
            date: Date in YYYY-MM-DD format
            limit: Maximum entries to return

        Returns:
            List of UnifiedLeaderboardEntry sorted by rank
        """
        key = (game_type, date)
        scores = self._scores.get(key, [])

        # Sort scores using game-specific ranking
        sorted_scores = sorted(
            scores,
            key=lambda s: self._sort_key(s),
            reverse=self._should_reverse_sort(game_type)
        )

        # Take top N and create entries with ranks
        entries = []
        for rank, score in enumerate(sorted_scores[:limit], start=1):
            entry = UnifiedLeaderboardEntry(
                id=score.id,
                rank=rank,
                username=score.username,
                score=score.score,
                game_type=score.game_type,
                date=score.date,
                metadata=score.metadata
            )
            entries.append(entry)

        return entries

    def sync_scores(
        self,
        scores: List[Dict]
    ) -> List[Dict]:
        """
        Batch syncs multiple scores.

        Args:
            scores: List of score dictionaries

        Returns:
            List of sync results
        """
        results = []
        for score_data in scores:
            try:
                game_score = self.submit_score(
                    game_type=score_data.get("game_type"),
                    score=score_data.get("score", 0),
                    date=score_data.get("date"),
                    username=score_data.get("username"),
                    metadata=score_data.get("metadata", {})
                )
                results.append({
                    "local_id": score_data.get("local_id"),
                    "remote_id": game_score.id,
                    "success": True,
                    "error": None
                })
            except Exception as e:
                results.append({
                    "local_id": score_data.get("local_id"),
                    "remote_id": "",
                    "success": False,
                    "error": str(e)
                })
        return results

    def _sort_key(self, score: GameScore):
        """Returns the sort key for a score based on game type."""
        if score.game_type == "wordle":
            # Sort by guesses (asc), then time (asc)
            guesses = int(score.metadata.get("guesses", 999))
            time_secs = int(score.metadata.get("time_seconds", 999999))
            return (guesses, time_secs)
        elif score.game_type == "crossword":
            # Sort by completion time (asc)
            return int(score.metadata.get("completion_time_seconds", 999999))
        else:
            # Echo, Trivia: sort by score (desc handled by reverse)
            return score.score

    def _should_reverse_sort(self, game_type: str) -> bool:
        """Returns whether to reverse sort (for high-score-wins games)."""
        return game_type in ["echo", "trivia"]

    def clear_scores(self, game_type: Optional[str] = None, date: Optional[str] = None):
        """Clears scores from storage."""
        if game_type and date:
            self._scores.pop((game_type, date), None)
        elif game_type:
            keys_to_remove = [k for k in self._scores if k[0] == game_type]
            for key in keys_to_remove:
                del self._scores[key]
        else:
            self._scores.clear()


# Module-level singleton
unified_leaderboard_service = UnifiedLeaderboardService()
