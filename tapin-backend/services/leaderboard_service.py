#
#  leaderboard_service.py
#  TapInApp - Wordle Leaderboard Server
#
#  MARK: - Leaderboard Service
#  This service handles all leaderboard business logic including:
#  - Username generation (Adjective+Noun format)
#  - Score submission and storage (Firestore-backed)
#  - Leaderboard retrieval and ranking
#
#  Architecture:
#  - Uses Firestore for persistent score storage
#  - Singleton pattern via module-level instance
#  - Scores are organized by puzzle date for daily leaderboards
#
#  Firestore Structure:
#  - Collection: wordle_scores / {puzzle_date} / scores / {score_id}
#

import logging
import random
from typing import List, Optional
from models import Score, LeaderboardEntry
from services.firestore_client import get_firestore_client

logger = logging.getLogger(__name__)


# ------------------------------------------------------------------------------
# MARK: - Username Generation Data
# ------------------------------------------------------------------------------

ADJECTIVES = [
    "Swift", "Brave", "Clever", "Mighty", "Noble",
    "Bold", "Quick", "Sharp", "Bright", "Keen",
    "Agile", "Fierce", "Lucky", "Calm", "Wise",
    "Golden", "Silver", "Cosmic", "Epic", "Grand",
    "Royal", "Mystic", "Ancient", "Stellar", "Thunder"
]

NOUNS = [
    "Falcon", "Otter", "Wolf", "Eagle", "Bear",
    "Tiger", "Lion", "Hawk", "Fox", "Deer",
    "Panda", "Koala", "Shark", "Dragon", "Phoenix",
    "Mustang", "Aggie", "Knight", "Warrior", "Champion",
    "Legend", "Pioneer", "Voyager", "Ranger", "Scout"
]

# Firestore collection name
SCORES_COLLECTION = "wordle_scores"


# ------------------------------------------------------------------------------
# MARK: - LeaderboardService Class
# ------------------------------------------------------------------------------

class LeaderboardService:
    """
    Service class for managing Wordle leaderboard operations.
    Backed by Firestore for persistent storage.
    """

    # --------------------------------------------------------------------------
    # MARK: - Username Generation
    # --------------------------------------------------------------------------

    def generate_username(self) -> str:
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
        Submits a new score to the leaderboard (persisted to Firestore).
        """
        if not 1 <= guesses <= 6:
            raise ValueError("Guesses must be between 1 and 6")

        if username is None:
            username = self.generate_username()

        score = Score(
            username=username,
            guesses=guesses,
            time_seconds=time_seconds,
            puzzle_date=puzzle_date
        )

        try:
            db = get_firestore_client()
            doc_ref = (
                db.collection(SCORES_COLLECTION)
                  .document(puzzle_date)
                  .collection("scores")
                  .document(score.id)
            )
            doc_ref.set(score.to_dict())
            logger.info(f"Score saved to Firestore: {score.id} for {puzzle_date}")
        except Exception as e:
            logger.error(f"Failed to save score to Firestore: {e}")
            # Still return the score so the user gets a response

        return score

    # --------------------------------------------------------------------------
    # MARK: - Leaderboard Retrieval
    # --------------------------------------------------------------------------

    def get_leaderboard(self, puzzle_date: str, limit: int = 5) -> List[LeaderboardEntry]:
        """
        Retrieves the top scores for a specific puzzle date from Firestore.
        Ranked by fewest guesses, then fastest time.
        """
        scores: List[Score] = []

        try:
            db = get_firestore_client()
            docs = (
                db.collection(SCORES_COLLECTION)
                  .document(puzzle_date)
                  .collection("scores")
                  .stream()
            )
            for doc in docs:
                try:
                    scores.append(Score.from_dict(doc.to_dict()))
                except (KeyError, TypeError) as e:
                    logger.warning(f"Skipping malformed score doc {doc.id}: {e}")
        except Exception as e:
            logger.error(f"Failed to fetch leaderboard from Firestore: {e}")
            return []

        # Sort by guesses (ascending), then by time (ascending) as tiebreaker
        sorted_scores = sorted(scores, key=lambda s: (s.guesses, s.time_seconds))
        top_scores = sorted_scores[:limit]

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
        return "🟩" * guesses


# ------------------------------------------------------------------------------
# MARK: - Module-level Instance
# ------------------------------------------------------------------------------

leaderboard_service = LeaderboardService()
