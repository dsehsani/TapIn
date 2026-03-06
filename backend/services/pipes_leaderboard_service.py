#
#  pipes_leaderboard_service.py
#  TapInApp - Backend Server
#
#  MARK: - Pipes Leaderboard Service
#  Handles score submission and leaderboard retrieval for the Pipes game.
#  Modeled after the Wordle leaderboard_service.py.
#
#  Firestore Structure:
#  - Collection: pipes_scores / {puzzle_date} / scores / {score_id}
#
#  Ranking:
#  - Primary: puzzles_completed (descending — more is better)
#  - Secondary: total_moves (ascending — fewer is better)
#  - Tertiary: total_time_seconds (ascending — faster is better)
#

import logging
import random
from typing import List, Optional
from models import PipesScore, PipesLeaderboardEntry
from services.firestore_client import get_firestore_client

logger = logging.getLogger(__name__)

SCORES_COLLECTION = "pipes_scores"

# Reuse the same fun username generator as Wordle
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


class PipesLeaderboardService:

    def generate_username(self) -> str:
        adjective = random.choice(ADJECTIVES)
        noun = random.choice(NOUNS)
        return f"{adjective}{noun}"

    def submit_score(
        self,
        puzzles_completed: int,
        total_moves: int,
        total_time_seconds: int,
        puzzle_date: str,
        username: Optional[str] = None
    ) -> PipesScore:
        if not 1 <= puzzles_completed <= 5:
            raise ValueError("puzzles_completed must be between 1 and 5")

        if username is None:
            username = self.generate_username()

        score = PipesScore(
            username=username,
            puzzles_completed=puzzles_completed,
            total_moves=total_moves,
            total_time_seconds=total_time_seconds,
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
            logger.info(f"Pipes score saved: {score.id} for {puzzle_date}")
        except Exception as e:
            logger.error(f"Failed to save pipes score to Firestore: {e}")

        return score

    def get_leaderboard(self, puzzle_date: str, limit: int = 5) -> List[PipesLeaderboardEntry]:
        scores: List[PipesScore] = []

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
                    scores.append(PipesScore.from_dict(doc.to_dict()))
                except (KeyError, TypeError) as e:
                    logger.warning(f"Skipping malformed pipes score doc {doc.id}: {e}")
        except Exception as e:
            logger.error(f"Failed to fetch pipes leaderboard from Firestore: {e}")
            return []

        # Sort: most puzzles completed, then fewest moves, then fastest time
        sorted_scores = sorted(
            scores,
            key=lambda s: (-s.puzzles_completed, s.total_moves, s.total_time_seconds)
        )
        top_scores = sorted_scores[:limit]

        entries = []
        for rank, score in enumerate(top_scores, start=1):
            entry = PipesLeaderboardEntry(
                rank=rank,
                username=score.username,
                puzzles_completed=score.puzzles_completed,
                total_moves=score.total_moves,
                total_time_seconds=score.total_time_seconds
            )
            entries.append(entry)

        return entries


pipes_leaderboard_service = PipesLeaderboardService()
