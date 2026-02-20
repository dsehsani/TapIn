#
#  user_repository.py
#  TapInApp - Backend Server
#
#  MARK: - User Firestore Repository
#  All read/write operations for user profile documents.
#
#  Firestore collection: "users"
#  Document ID: user UUID (set at registration)
#
#  Document schema:
#    id, username, email, passwordHash, createdAt, updatedAt,
#    gameStats { wordle, echo, trivia, crossword },
#    savedArticles [], readArticles [], eventRSVPs []
#

import uuid
import logging
from datetime import datetime, timezone
from typing import Optional

from services.firestore_client import get_firestore_client

logger = logging.getLogger(__name__)

_COLLECTION = "users"

# Valid game type keys — used for validation before writing
VALID_GAME_TYPES = {"wordle", "echo", "trivia", "crossword"}


# ------------------------------------------------------------------------------
# MARK: - Default Document Shape
# ------------------------------------------------------------------------------

def _default_game_stats() -> dict:
    return {
        "wordle": {
            "solveCount": 0,
            "bestGuesses": None,
            "bestTimeSeconds": None,
            "totalGuesses": 0,
            "totalTimeSeconds": 0,
        },
        "echo": {
            "solveCount": 0,
            "bestScore": None,
            "totalScore": 0,
        },
        "trivia": {
            "solveCount": 0,
            "bestScore": None,
        },
        "crossword": {
            "solveCount": 0,
            "bestTimeSeconds": None,
        },
    }


def _now_iso() -> str:
    return datetime.now(tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


# ------------------------------------------------------------------------------
# MARK: - UserRepository
# ------------------------------------------------------------------------------

class UserRepository:

    def _col(self):
        return get_firestore_client().collection(_COLLECTION)

    # --------------------------------------------------------------------------
    # MARK: - Create
    # --------------------------------------------------------------------------

    def create_user(self, username: str, email: str, password_hash: str) -> dict:
        """
        Creates a new user document.
        Raises ValueError if username or email is already taken (checked atomically).
        Returns the created user dict (without passwordHash).
        """
        db = get_firestore_client()
        col = db.collection(_COLLECTION)

        # Check uniqueness atomically via transaction
        @db.transaction
        def _create(transaction):
            # Check username
            existing_username = list(
                col.where("username", "==", username).limit(1).stream()
            )
            if existing_username:
                raise ValueError("username_taken")

            # Check email
            existing_email = list(
                col.where("email", "==", email).limit(1).stream()
            )
            if existing_email:
                raise ValueError("email_taken")

            user_id = str(uuid.uuid4())
            now = _now_iso()
            doc = {
                "id": user_id,
                "username": username,
                "email": email,
                "passwordHash": password_hash,
                "createdAt": now,
                "updatedAt": now,
                "gameStats": _default_game_stats(),
                "savedArticles": [],
                "readArticles": [],
                "eventRSVPs": [],
            }
            transaction.set(col.document(user_id), doc)
            return doc

        doc = _create()
        logger.info(f"Created user '{username}' (id={doc['id']})")
        return {k: v for k, v in doc.items() if k != "passwordHash"}

    # --------------------------------------------------------------------------
    # MARK: - Read
    # --------------------------------------------------------------------------

    def get_user_by_id(self, user_id: str) -> Optional[dict]:
        """Returns the user document for user_id, or None if not found."""
        try:
            snap = self._col().document(user_id).get()
            return snap.to_dict() if snap.exists else None
        except Exception as e:
            logger.error(f"get_user_by_id failed for '{user_id}': {e}")
            return None

    def get_user_by_username(self, username: str) -> Optional[dict]:
        """Returns the user document matching username, or None."""
        try:
            results = list(
                self._col().where("username", "==", username).limit(1).stream()
            )
            return results[0].to_dict() if results else None
        except Exception as e:
            logger.error(f"get_user_by_username failed for '{username}': {e}")
            return None

    def get_user_by_email(self, email: str) -> Optional[dict]:
        """Returns the user document matching email, or None."""
        try:
            results = list(
                self._col().where("email", "==", email).limit(1).stream()
            )
            return results[0].to_dict() if results else None
        except Exception as e:
            logger.error(f"get_user_by_email failed for '{email}': {e}")
            return None

    # --------------------------------------------------------------------------
    # MARK: - Game Stats
    # --------------------------------------------------------------------------

    def update_game_stats(self, user_id: str, game_type: str, stats: dict) -> None:
        """
        Replaces the stats block for a single game type.
        game_type must be one of VALID_GAME_TYPES.
        """
        try:
            self._col().document(user_id).update({
                f"gameStats.{game_type}": stats,
                "updatedAt": _now_iso(),
            })
            logger.info(f"Updated {game_type} stats for user '{user_id}'")
        except Exception as e:
            logger.error(f"update_game_stats failed for '{user_id}': {e}")
            raise

    # --------------------------------------------------------------------------
    # MARK: - Saved Articles
    # --------------------------------------------------------------------------

    def add_saved_article(self, user_id: str, article: dict) -> None:
        """
        Adds an article to savedArticles. No-ops if the article_id is already present.
        article dict must contain at least: articleId, articleURL, title.
        savedAt is injected here if not provided.
        """
        try:
            from google.cloud.firestore import ArrayUnion  # lazy

            if "savedAt" not in article:
                article = {**article, "savedAt": _now_iso()}

            # Use ArrayUnion — Firestore deduplicates exact-match dicts
            self._col().document(user_id).update({
                "savedArticles": ArrayUnion([article]),
                "updatedAt": _now_iso(),
            })
        except Exception as e:
            logger.error(f"add_saved_article failed for '{user_id}': {e}")
            raise

    def remove_saved_article(self, user_id: str, article_id: str) -> None:
        """Removes the article with the given article_id from savedArticles."""
        try:
            snap = self._col().document(user_id).get()
            if not snap.exists:
                return
            data = snap.to_dict()
            filtered = [a for a in data.get("savedArticles", [])
                        if a.get("articleId") != article_id]
            self._col().document(user_id).update({
                "savedArticles": filtered,
                "updatedAt": _now_iso(),
            })
        except Exception as e:
            logger.error(f"remove_saved_article failed for '{user_id}': {e}")
            raise

    # --------------------------------------------------------------------------
    # MARK: - Read Articles
    # --------------------------------------------------------------------------

    def add_read_article(self, user_id: str, article_id: str) -> None:
        """
        Marks an article as read. No-ops if the article_id is already in the list.
        """
        try:
            snap = self._col().document(user_id).get()
            if not snap.exists:
                return
            data = snap.to_dict()
            already_read = any(
                r.get("articleId") == article_id
                for r in data.get("readArticles", [])
            )
            if already_read:
                return

            from google.cloud.firestore import ArrayUnion  # lazy
            self._col().document(user_id).update({
                "readArticles": ArrayUnion([{
                    "articleId": article_id,
                    "readAt": _now_iso(),
                }]),
                "updatedAt": _now_iso(),
            })
        except Exception as e:
            logger.error(f"add_read_article failed for '{user_id}': {e}")
            raise

    # --------------------------------------------------------------------------
    # MARK: - Event RSVPs
    # --------------------------------------------------------------------------

    def add_event_rsvp(self, user_id: str, event: dict) -> None:
        """
        Adds an event RSVP. No-ops if event_id is already present.
        event dict must contain: eventId, eventTitle.
        rsvpAt is injected here if not provided.
        """
        try:
            snap = self._col().document(user_id).get()
            if not snap.exists:
                return
            data = snap.to_dict()
            already_rsvped = any(
                r.get("eventId") == event.get("eventId")
                for r in data.get("eventRSVPs", [])
            )
            if already_rsvped:
                return

            if "rsvpAt" not in event:
                event = {**event, "rsvpAt": _now_iso()}

            from google.cloud.firestore import ArrayUnion  # lazy
            self._col().document(user_id).update({
                "eventRSVPs": ArrayUnion([event]),
                "updatedAt": _now_iso(),
            })
        except Exception as e:
            logger.error(f"add_event_rsvp failed for '{user_id}': {e}")
            raise

    def remove_event_rsvp(self, user_id: str, event_id: str) -> None:
        """Removes the RSVP with the given event_id from eventRSVPs."""
        try:
            snap = self._col().document(user_id).get()
            if not snap.exists:
                return
            data = snap.to_dict()
            filtered = [r for r in data.get("eventRSVPs", [])
                        if r.get("eventId") != event_id]
            self._col().document(user_id).update({
                "eventRSVPs": filtered,
                "updatedAt": _now_iso(),
            })
        except Exception as e:
            logger.error(f"remove_event_rsvp failed for '{user_id}': {e}")
            raise

    # --------------------------------------------------------------------------
    # MARK: - Delete
    # --------------------------------------------------------------------------

    def delete_user(self, user_id: str) -> None:
        """Permanently deletes the user document."""
        try:
            self._col().document(user_id).delete()
            logger.info(f"Deleted user '{user_id}'")
        except Exception as e:
            logger.error(f"delete_user failed for '{user_id}': {e}")
            raise


# Singleton
user_repository = UserRepository()
