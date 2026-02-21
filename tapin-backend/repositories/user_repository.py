#
#  user_repository.py
#  TapIn Backend
#
#  Firestore repository for user profiles.
#  Supports social auth (Apple, Phone) and email/password.
#
#  Collection: "users"
#  Document schema:
#    id, username, email, authProvider, appleUserId, googleUserId, phoneNumber,
#    passwordHash, createdAt, updatedAt,
#    gameStats {}, savedArticles [], readArticles [], eventRSVPs []
#

import uuid
import logging
from datetime import datetime, timezone
from typing import Optional

from services.firestore_client import get_firestore_client

logger = logging.getLogger(__name__)

_COLLECTION = "users"
VALID_GAME_TYPES = {"wordle", "echo", "trivia", "crossword", "overall"}


def _default_game_stats() -> dict:
    return {
        "wordle": {"solveCount": 0, "bestGuesses": None, "bestTimeSeconds": None, "totalGuesses": 0, "totalTimeSeconds": 0},
        "echo": {"solveCount": 0, "bestScore": None, "totalScore": 0},
        "trivia": {"solveCount": 0, "bestScore": None},
        "crossword": {"solveCount": 0, "bestTimeSeconds": None},
        "overall": {"gamesPlayed": 0, "wins": 0, "currentStreak": 0, "maxStreak": 0, "lastPlayedDate": None},
    }


def _now_iso() -> str:
    return datetime.now(tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


class UserRepository:

    def _col(self):
        return get_firestore_client().collection(_COLLECTION)

    # --------------------------------------------------------------------------
    # Create
    # --------------------------------------------------------------------------

    def create_user(self, username: str, email: str, password_hash: str) -> dict:
        """Create user with email/password auth. Raises ValueError if taken."""
        return self._create_user_doc(
            username=username, email=email,
            auth_provider="email", password_hash=password_hash,
        )

    def create_social_user(self, auth_provider: str, username: str,
                           email: str = "", apple_user_id: str = "",
                           phone_number: str = "", google_user_id: str = "") -> dict:
        """Create user from social auth (Apple, Google, Phone). No password needed."""
        return self._create_user_doc(
            username=username, email=email,
            auth_provider=auth_provider,
            apple_user_id=apple_user_id,
            phone_number=phone_number,
            google_user_id=google_user_id,
        )

    def _create_user_doc(self, username: str, email: str, auth_provider: str,
                         password_hash: str = "", apple_user_id: str = "",
                         phone_number: str = "", google_user_id: str = "") -> dict:
        db = get_firestore_client()
        col = db.collection(_COLLECTION)

        user_id = str(uuid.uuid4())
        now = _now_iso()
        doc = {
            "id": user_id,
            "username": username,
            "email": email,
            "authProvider": auth_provider,
            "appleUserId": apple_user_id,
            "googleUserId": google_user_id,
            "phoneNumber": phone_number,
            "passwordHash": password_hash,
            "createdAt": now,
            "updatedAt": now,
            "gameStats": _default_game_stats(),
            "savedArticles": [],
            "readArticles": [],
            "eventRSVPs": [],
        }
        col.document(user_id).set(doc)
        logger.info(f"Created user '{username}' via {auth_provider} (id={user_id})")
        return {k: v for k, v in doc.items() if k != "passwordHash"}

    # --------------------------------------------------------------------------
    # Read
    # --------------------------------------------------------------------------

    def get_user_by_id(self, user_id: str) -> Optional[dict]:
        try:
            snap = self._col().document(user_id).get()
            return snap.to_dict() if snap.exists else None
        except Exception as e:
            logger.error(f"get_user_by_id failed: {e}")
            return None

    def get_user_by_username(self, username: str) -> Optional[dict]:
        try:
            results = list(self._col().where("username", "==", username).limit(1).stream())
            return results[0].to_dict() if results else None
        except Exception as e:
            logger.error(f"get_user_by_username failed: {e}")
            return None

    def get_user_by_email(self, email: str) -> Optional[dict]:
        try:
            results = list(self._col().where("email", "==", email).limit(1).stream())
            return results[0].to_dict() if results else None
        except Exception as e:
            logger.error(f"get_user_by_email failed: {e}")
            return None

    def get_user_by_apple_id(self, apple_user_id: str) -> Optional[dict]:
        try:
            results = list(self._col().where("appleUserId", "==", apple_user_id).limit(1).stream())
            return results[0].to_dict() if results else None
        except Exception as e:
            logger.error(f"get_user_by_apple_id failed: {e}")
            return None

    def get_user_by_google_id(self, google_user_id: str) -> Optional[dict]:
        try:
            results = list(self._col().where("googleUserId", "==", google_user_id).limit(1).stream())
            return results[0].to_dict() if results else None
        except Exception as e:
            logger.error(f"get_user_by_google_id failed: {e}")
            return None

    def get_user_by_phone(self, phone_number: str) -> Optional[dict]:
        try:
            results = list(self._col().where("phoneNumber", "==", phone_number).limit(1).stream())
            return results[0].to_dict() if results else None
        except Exception as e:
            logger.error(f"get_user_by_phone failed: {e}")
            return None

    # --------------------------------------------------------------------------
    # Update Profile
    # --------------------------------------------------------------------------

    def update_profile(self, user_id: str, fields: dict) -> None:
        """Update allowed profile fields (username, email).
        If email is provided, checks uniqueness first."""
        allowed = {"username", "email"}
        updates = {k: v for k, v in fields.items() if k in allowed}
        if not updates:
            return

        # Enforce email uniqueness
        new_email = updates.get("email", "").strip().lower()
        if new_email:
            existing = self.get_user_by_email(new_email)
            if existing and existing["id"] != user_id:
                raise ValueError("Email already registered to another account")
            updates["email"] = new_email

        updates["updatedAt"] = _now_iso()
        self._col().document(user_id).update(updates)

    def link_auth_provider(self, user_id: str, **kwargs) -> dict:
        """Link an additional auth provider to an existing user.
        Accepts appleUserId, phoneNumber as keyword args."""
        allowed = {"appleUserId", "googleUserId", "phoneNumber"}
        updates = {k: v for k, v in kwargs.items() if k in allowed and v}
        if not updates:
            return self.get_user_by_id(user_id)
        updates["updatedAt"] = _now_iso()
        self._col().document(user_id).update(updates)
        logger.info(f"Linked auth provider to user {user_id}: {list(updates.keys())}")
        return self.get_user_by_id(user_id)

    # --------------------------------------------------------------------------
    # Game Stats
    # --------------------------------------------------------------------------

    def update_game_stats(self, user_id: str, game_type: str, stats: dict) -> None:
        self._col().document(user_id).update({
            f"gameStats.{game_type}": stats,
            "updatedAt": _now_iso(),
        })

    # --------------------------------------------------------------------------
    # Saved Articles
    # --------------------------------------------------------------------------

    def add_saved_article(self, user_id: str, article: dict) -> None:
        from google.cloud.firestore import ArrayUnion
        if "savedAt" not in article:
            article = {**article, "savedAt": _now_iso()}
        self._col().document(user_id).update({
            "savedArticles": ArrayUnion([article]),
            "updatedAt": _now_iso(),
        })

    def remove_saved_article(self, user_id: str, article_id: str) -> None:
        snap = self._col().document(user_id).get()
        if not snap.exists:
            return
        data = snap.to_dict()
        filtered = [a for a in data.get("savedArticles", []) if a.get("articleId") != article_id]
        self._col().document(user_id).update({"savedArticles": filtered, "updatedAt": _now_iso()})

    # --------------------------------------------------------------------------
    # Read Articles
    # --------------------------------------------------------------------------

    def add_read_article(self, user_id: str, article_id: str) -> None:
        snap = self._col().document(user_id).get()
        if not snap.exists:
            return
        data = snap.to_dict()
        if any(r.get("articleId") == article_id for r in data.get("readArticles", [])):
            return
        from google.cloud.firestore import ArrayUnion
        self._col().document(user_id).update({
            "readArticles": ArrayUnion([{"articleId": article_id, "readAt": _now_iso()}]),
            "updatedAt": _now_iso(),
        })

    # --------------------------------------------------------------------------
    # Event RSVPs
    # --------------------------------------------------------------------------

    def add_event_rsvp(self, user_id: str, event: dict) -> None:
        snap = self._col().document(user_id).get()
        if not snap.exists:
            return
        data = snap.to_dict()
        if any(r.get("eventId") == event.get("eventId") for r in data.get("eventRSVPs", [])):
            return
        if "rsvpAt" not in event:
            event = {**event, "rsvpAt": _now_iso()}
        from google.cloud.firestore import ArrayUnion
        self._col().document(user_id).update({
            "eventRSVPs": ArrayUnion([event]),
            "updatedAt": _now_iso(),
        })

    def remove_event_rsvp(self, user_id: str, event_id: str) -> None:
        snap = self._col().document(user_id).get()
        if not snap.exists:
            return
        data = snap.to_dict()
        filtered = [r for r in data.get("eventRSVPs", []) if r.get("eventId") != event_id]
        self._col().document(user_id).update({"eventRSVPs": filtered, "updatedAt": _now_iso()})

    # --------------------------------------------------------------------------
    # Delete
    # --------------------------------------------------------------------------

    def delete_user(self, user_id: str) -> None:
        self._col().document(user_id).delete()
        logger.info(f"Deleted user '{user_id}'")


user_repository = UserRepository()
