#
#  score_repository.py
#  TapInApp - Wordle Leaderboard Server
#
#  MARK: - Score Repository
#  This repository handles all Firestore operations for Score documents.
#  Abstracts database operations from business logic.
#

import logging
from typing import List
from google.cloud.firestore_v1.base_query import FieldFilter
from services.firestore_client import get_firestore_client
from models import Score

# Configure logging
logger = logging.getLogger(__name__)

# Firestore collection name
SCORES_COLLECTION = "scores"


class ScoreRepository:
    """
    Repository for Score document operations in Firestore.

    Provides CRUD operations for scores with the following collection structure:
    - Collection: "scores"
    - Document ID: Score UUID
    - Fields: username, guesses, time_seconds, puzzle_date, created_at
    """

    def __init__(self):
        """Initialize the repository."""
        pass  # Client is obtained per-operation for thread safety

    def _get_collection(self):
        """Get the scores collection reference."""
        client = get_firestore_client()
        return client.collection(SCORES_COLLECTION)

    def save_score(self, score: Score) -> Score:
        """
        Saves a score document to Firestore.

        Args:
            score: The Score object to save

        Returns:
            The saved Score object (unchanged)

        Raises:
            Exception: If the save operation fails
        """
        try:
            collection = self._get_collection()

            # Use the score's ID as the document ID
            doc_ref = collection.document(score.id)

            # Convert to Firestore-compatible dict
            doc_data = score.to_firestore_dict()

            # Save to Firestore
            doc_ref.set(doc_data)

            logger.info(f"Saved score {score.id} for date {score.puzzle_date}")
            return score

        except Exception as e:
            logger.error(f"Failed to save score: {e}")
            raise

    def get_scores_by_date(self, puzzle_date: str, limit: int = 100) -> List[Score]:
        """
        Retrieves scores for a specific puzzle date, sorted for leaderboard.

        Scores are sorted by:
        1. Number of guesses (ascending - fewer is better)
        2. Time in seconds (ascending - faster is better)

        Args:
            puzzle_date: The puzzle date in YYYY-MM-DD format
            limit: Maximum number of scores to return (default: 100)

        Returns:
            List of Score objects sorted by rank

        Raises:
            Exception: If the query fails
        """
        try:
            collection = self._get_collection()

            # Query: filter by date, order by guesses then time, limit results
            query = (
                collection
                .where(filter=FieldFilter("puzzle_date", "==", puzzle_date))
                .order_by("guesses")
                .order_by("time_seconds")
                .limit(limit)
            )

            # Execute query
            docs = query.stream()

            # Convert documents to Score objects
            scores = []
            for doc in docs:
                score = Score.from_firestore(doc)
                scores.append(score)

            logger.info(f"Retrieved {len(scores)} scores for date {puzzle_date}")
            return scores

        except Exception as e:
            logger.error(f"Failed to get scores for date {puzzle_date}: {e}")
            raise

    def delete_scores_by_date(self, puzzle_date: str) -> int:
        """
        Deletes all scores for a specific puzzle date.

        Primarily used for testing and data cleanup.

        Args:
            puzzle_date: The puzzle date in YYYY-MM-DD format

        Returns:
            Number of documents deleted

        Raises:
            Exception: If the delete operation fails
        """
        try:
            collection = self._get_collection()

            # Query all scores for this date
            query = collection.where(
                filter=FieldFilter("puzzle_date", "==", puzzle_date)
            )
            docs = query.stream()

            # Delete each document
            deleted_count = 0
            for doc in docs:
                doc.reference.delete()
                deleted_count += 1

            logger.info(f"Deleted {deleted_count} scores for date {puzzle_date}")
            return deleted_count

        except Exception as e:
            logger.error(f"Failed to delete scores for date {puzzle_date}: {e}")
            raise

    def delete_all_scores(self) -> int:
        """
        Deletes all scores from the collection.

        WARNING: Use with caution! Primarily for testing.

        Returns:
            Number of documents deleted
        """
        try:
            collection = self._get_collection()
            docs = collection.stream()

            deleted_count = 0
            for doc in docs:
                doc.reference.delete()
                deleted_count += 1

            logger.info(f"Deleted all {deleted_count} scores")
            return deleted_count

        except Exception as e:
            logger.error(f"Failed to delete all scores: {e}")
            raise


# Singleton instance for use across the application
score_repository = ScoreRepository()
