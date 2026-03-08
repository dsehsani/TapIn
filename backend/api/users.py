#
#  users.py
#  TapIn Backend
#
#  User API with social auth (Apple, Google, Phone) and email/password.
#
#  Public endpoints:
#    POST /api/users/auth/apple    — Apple Sign-In
#    POST /api/users/auth/google   — Google Sign-In
#    POST /api/users/auth/phone    — Phone (SMS) auth
#    POST /api/users/register      — Email/password registration
#    POST /api/users/login         — Email/password login
#    GET  /api/users/health        — Health check
#
#  Protected endpoints (Bearer token):
#    GET    /api/users/me                       — fetch profile
#    PATCH  /api/users/me                       — update profile (email, username)
#    DELETE /api/users/me                       — delete account
#    PATCH  /api/users/me/games/<game_type>     — update game stats
#    GET    /api/users/me/articles/saved        — list saved articles
#    POST   /api/users/me/articles/saved        — save article
#    DELETE /api/users/me/articles/saved/<id>   — unsave article
#    POST   /api/users/me/articles/read         — mark article read
#    GET    /api/users/me/articles/read         — list read articles
#    GET    /api/users/me/events                — list RSVPs
#    POST   /api/users/me/events                — RSVP to event
#    DELETE /api/users/me/events/<event_id>     — cancel RSVP
#

import base64
import logging
import uuid

from flask import Blueprint, request, jsonify, g
from google.cloud import storage as gcs

from services import auth_service
from services.firestore_client import is_firestore_connected
from services.moderation import moderation_service
from repositories.user_repository import user_repository, VALID_GAME_TYPES
from middleware.auth_middleware import require_auth

_GCS_BUCKET = "tapin-profile-images"

logger = logging.getLogger(__name__)

users_bp = Blueprint("users", __name__, url_prefix="/api/users")


def _public_profile(user: dict) -> dict:
    return {k: v for k, v in user.items() if k != "passwordHash"}


# --------------------------------------------------------------------------
# Apple Sign-In
# --------------------------------------------------------------------------

@users_bp.route("/auth/apple", methods=["POST"])
def auth_apple():
    """
    Authenticate via Apple Sign-In.

    Request JSON: {
        "identityToken": str,    — Apple identity token (JWT)
        "appleUserId": str,      — Apple user ID
        "displayName": str,      — (optional) user's name
        "email": str             — (optional) user's email
    }
    Response: { "success": true, "token": str, "user": {...}, "isNewUser": bool }
    """
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"success": False, "error": "Request body must be JSON"}), 400

    identity_token = data.get("identityToken", "")
    apple_user_id = data.get("appleUserId", "")

    if not identity_token or not apple_user_id:
        return jsonify({"success": False, "error": "identityToken and appleUserId are required"}), 400

    try:
        # Verify the Apple identity token
        claims = auth_service.verify_apple_token(identity_token)

        # Ensure the token's subject matches the provided Apple user ID
        if claims.get("sub") != apple_user_id:
            return jsonify({"success": False, "error": "Token subject mismatch"}), 401

        # Check if user already exists by Apple ID
        existing = user_repository.get_user_by_apple_id(apple_user_id)
        if existing:
            token = auth_service.create_token(existing["id"])
            return jsonify({
                "success": True, "token": token,
                "user": _public_profile(existing), "isNewUser": False,
            }), 200

        display_name = data.get("displayName", "").strip() or "Aggie Student"
        email = data.get("email", claims.get("email", "")).strip().lower()

        # Check if a user with this email already exists (e.g. created via phone auth).
        # If so, link the Apple ID to the existing account instead of creating a duplicate.
        if email:
            existing_by_email = user_repository.get_user_by_email(email)
            if existing_by_email:
                linked = user_repository.link_auth_provider(
                    existing_by_email["id"], appleUserId=apple_user_id
                )
                token = auth_service.create_token(existing_by_email["id"])
                return jsonify({
                    "success": True, "token": token,
                    "user": _public_profile(linked), "isNewUser": False,
                }), 200

        # Create new user
        user = user_repository.create_social_user(
            auth_provider="apple",
            username=display_name,
            email=email,
            apple_user_id=apple_user_id,
        )
        token = auth_service.create_token(user["id"])
        return jsonify({
            "success": True, "token": token,
            "user": user, "isNewUser": True,
        }), 201

    except ValueError as e:
        return jsonify({"success": False, "error": str(e)}), 401
    except Exception as e:
        logger.error(f"Apple auth error: {e}")
        return jsonify({"success": False, "error": "Internal server error"}), 500


# --------------------------------------------------------------------------
# Google Sign-In
# --------------------------------------------------------------------------

@users_bp.route("/auth/google", methods=["POST"])
def auth_google():
    """
    Authenticate via Google Sign-In.

    Request JSON: {
        "idToken": str,          — Google ID token (JWT)
        "googleUserId": str,     — Google user ID (sub claim)
        "displayName": str,      — (optional) user's name
        "email": str             — (optional) user's email
    }
    Response: { "success": true, "token": str, "user": {...}, "isNewUser": bool }
    """
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"success": False, "error": "Request body must be JSON"}), 400

    id_token = data.get("idToken", "")
    google_user_id = data.get("googleUserId", "")

    if not id_token or not google_user_id:
        return jsonify({"success": False, "error": "idToken and googleUserId are required"}), 400

    try:
        # Verify the Google ID token
        claims = auth_service.verify_google_token(id_token)

        # Ensure the token's subject matches the provided Google user ID
        if claims.get("sub") != google_user_id:
            return jsonify({"success": False, "error": "Token subject mismatch"}), 401

        # Check if user already exists by Google ID
        existing = user_repository.get_user_by_google_id(google_user_id)
        if existing:
            token = auth_service.create_token(existing["id"])
            return jsonify({
                "success": True, "token": token,
                "user": _public_profile(existing), "isNewUser": False,
            }), 200

        display_name = data.get("displayName", "").strip() or "Aggie Student"
        email = data.get("email", claims.get("email", "")).strip().lower()

        # Check if a user with this email already exists (e.g. created via Apple/phone).
        # If so, link the Google ID to the existing account instead of creating a duplicate.
        if email:
            existing_by_email = user_repository.get_user_by_email(email)
            if existing_by_email:
                linked = user_repository.link_auth_provider(
                    existing_by_email["id"], googleUserId=google_user_id
                )
                token = auth_service.create_token(existing_by_email["id"])
                return jsonify({
                    "success": True, "token": token,
                    "user": _public_profile(linked), "isNewUser": False,
                }), 200

        # Create new user
        user = user_repository.create_social_user(
            auth_provider="google",
            username=display_name,
            email=email,
            google_user_id=google_user_id,
        )
        token = auth_service.create_token(user["id"])
        return jsonify({
            "success": True, "token": token,
            "user": user, "isNewUser": True,
        }), 201

    except ValueError as e:
        return jsonify({"success": False, "error": str(e)}), 401
    except Exception as e:
        logger.error(f"Google auth error: {e}")
        return jsonify({"success": False, "error": "Internal server error"}), 500


# --------------------------------------------------------------------------
# Phone Auth
# --------------------------------------------------------------------------

@users_bp.route("/auth/phone", methods=["POST"])
def auth_phone():
    """
    Authenticate via Phone (Firebase Phone Auth).

    Request JSON: {
        "phoneNumber": str,          — E.164 format (e.g. "+14155551234")
        "firebaseIdToken": str,      — Firebase ID token from Phone Auth
        "displayName": str           — (optional) user's name
    }
    Response: { "success": true, "token": str, "user": {...}, "isNewUser": bool }
    """
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"success": False, "error": "Request body must be JSON"}), 400

    phone_number = data.get("phoneNumber", "").strip()
    firebase_id_token = data.get("firebaseIdToken", "").strip()

    if not phone_number or not firebase_id_token:
        return jsonify({"success": False, "error": "phoneNumber and firebaseIdToken are required"}), 400

    try:
        # Verify the Firebase ID token
        firebase_info = auth_service.verify_phone_token(firebase_id_token)

        # Ensure the phone number from Firebase matches what the client sent
        firebase_phone = firebase_info.get("phone_number", "")
        if firebase_phone and firebase_phone != phone_number:
            return jsonify({"success": False, "error": "Phone number mismatch"}), 401

        # Check if user already exists
        existing = user_repository.get_user_by_phone(phone_number)
        if existing:
            token = auth_service.create_token(existing["id"])
            return jsonify({
                "success": True, "token": token,
                "user": _public_profile(existing), "isNewUser": False,
            }), 200

        # Create new user
        display_name = data.get("displayName", "").strip() or "Aggie Student"

        user = user_repository.create_social_user(
            auth_provider="phone",
            username=display_name,
            phone_number=phone_number,
        )
        token = auth_service.create_token(user["id"])
        return jsonify({
            "success": True, "token": token,
            "user": user, "isNewUser": True,
        }), 201

    except ValueError as e:
        return jsonify({"success": False, "error": str(e)}), 401
    except Exception as e:
        logger.error(f"Phone auth error: {e}")
        return jsonify({"success": False, "error": "Internal server error"}), 500


# --------------------------------------------------------------------------
# Email/Password Registration
# --------------------------------------------------------------------------

@users_bp.route("/register", methods=["POST"])
def register():
    """
    Register with email and password.

    Request JSON: { "username": str, "email": str, "password": str }
    Response 201: { "success": true, "token": str, "user": {...} }
    """
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"success": False, "error": "Request body must be JSON"}), 400

    missing = [f for f in ("username", "email", "password") if not data.get(f)]
    if missing:
        return jsonify({"success": False, "error": f"Missing required fields: {', '.join(missing)}"}), 400

    username = data["username"].strip()
    email = data["email"].strip().lower()
    password = data["password"]

    if len(username) < 2 or len(username) > 30:
        return jsonify({"success": False, "error": "Username must be 2-30 characters"}), 400
    if len(password) < 6:
        return jsonify({"success": False, "error": "Password must be at least 6 characters"}), 400

    try:
        # Check if email already used
        if user_repository.get_user_by_email(email):
            return jsonify({"success": False, "error": "Email already registered"}), 409

        password_hash = auth_service.hash_password(password)
        user = user_repository.create_user(username, email, password_hash)
        token = auth_service.create_token(user["id"])
        return jsonify({"success": True, "token": token, "user": user}), 201

    except Exception as e:
        logger.error(f"Register error: {e}")
        return jsonify({"success": False, "error": "Internal server error"}), 500


# --------------------------------------------------------------------------
# Email/Password Login
# --------------------------------------------------------------------------

@users_bp.route("/login", methods=["POST"])
def login():
    """
    Login with email and password.

    Request JSON: { "email": str, "password": str }
    Response: { "success": true, "token": str, "user": {...} }
    """
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"success": False, "error": "Request body must be JSON"}), 400

    email = data.get("email", "").strip().lower()
    password = data.get("password", "")

    if not email or not password:
        return jsonify({"success": False, "error": "Email and password are required"}), 400

    try:
        user = user_repository.get_user_by_email(email)
        if not user or not auth_service.verify_password(password, user.get("passwordHash", "")):
            return jsonify({"success": False, "error": "Invalid credentials"}), 401

        token = auth_service.create_token(user["id"])
        return jsonify({"success": True, "token": token, "user": _public_profile(user)}), 200

    except Exception as e:
        logger.error(f"Login error: {e}")
        return jsonify({"success": False, "error": "Internal server error"}), 500


# --------------------------------------------------------------------------
# Protected: Profile
# --------------------------------------------------------------------------

@users_bp.route("/me", methods=["GET"])
@require_auth
def get_me():
    try:
        user = user_repository.get_user_by_id(g.user_id)
        if not user:
            return jsonify({"success": False, "error": "User not found"}), 404
        return jsonify({"success": True, "user": _public_profile(user)}), 200
    except Exception as e:
        logger.error(f"get_me error: {e}")
        return jsonify({"success": False, "error": "Internal server error"}), 500


@users_bp.route("/me", methods=["PATCH"])
@require_auth
def update_me():
    """
    Update the current user's profile.

    Request JSON: { "email": str (optional), "username": str (optional) }
    Response: { "success": true, "user": {...} }
    """
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"success": False, "error": "Request body must be JSON"}), 400

    # Moderate display name if being changed
    display_name = data.get("username") or data.get("displayName")
    if display_name and display_name.strip():
        try:
            if not moderation_service.moderate_display_name(display_name.strip()):
                return jsonify({
                    "success": False,
                    "error": "This display name is not allowed. Please choose a different name."
                }), 400
        except Exception as e:
            logger.error(f"Name moderation error (fail-closed): {e}")
            return jsonify({
                "success": False,
                "error": "Unable to verify display name. Please try again."
            }), 500

    try:
        user_repository.update_profile(g.user_id, data)
        updated = user_repository.get_user_by_id(g.user_id)
        return jsonify({"success": True, "user": _public_profile(updated)}), 200
    except ValueError as e:
        return jsonify({"success": False, "error": str(e)}), 409
    except Exception as e:
        logger.error(f"update_me error: {e}")
        return jsonify({"success": False, "error": "Internal server error"}), 500


@users_bp.route("/me/profile-image", methods=["POST"])
@require_auth
def upload_profile_image():
    """
    Upload a profile image (base64-encoded).

    Request JSON: { "imageData": "<base64 string>" }
    Response: { "success": true, "profileImageURL": "https://..." }
    """
    data = request.get_json(silent=True)
    if not data or not data.get("imageData"):
        return jsonify({"success": False, "error": "imageData is required"}), 400

    try:
        image_bytes = base64.b64decode(data["imageData"])

        # Limit to 5 MB
        if len(image_bytes) > 5 * 1024 * 1024:
            return jsonify({"success": False, "error": "Image must be under 5 MB"}), 400

        # Upload to GCS with a unique filename per user (overwrites previous)
        client = gcs.Client()
        bucket = client.bucket(_GCS_BUCKET)
        blob_name = f"profiles/{g.user_id}.jpg"
        blob = bucket.blob(blob_name)
        blob.upload_from_string(image_bytes, content_type="image/jpeg")

        public_url = f"https://storage.googleapis.com/{_GCS_BUCKET}/{blob_name}"

        # Save URL to user profile in Firestore
        user_repository.update_profile(g.user_id, {"profileImageURL": public_url})

        return jsonify({"success": True, "profileImageURL": public_url}), 200
    except Exception as e:
        logger.error(f"upload_profile_image error: {e}")
        return jsonify({"success": False, "error": "Failed to upload image"}), 500


@users_bp.route("/me", methods=["DELETE"])
@require_auth
def delete_me():
    try:
        user_repository.delete_user(g.user_id)
        return jsonify({"success": True}), 200
    except Exception as e:
        logger.error(f"delete_me error: {e}")
        return jsonify({"success": False, "error": "Internal server error"}), 500


# --------------------------------------------------------------------------
# Protected: Game Stats
# --------------------------------------------------------------------------

@users_bp.route("/me/games/<game_type>", methods=["PATCH"])
@require_auth
def update_game_stats(game_type: str):
    if game_type not in VALID_GAME_TYPES:
        return jsonify({"success": False, "error": f"Invalid game_type. Must be one of: {', '.join(sorted(VALID_GAME_TYPES))}"}), 400

    stats = request.get_json(silent=True)
    if stats is None:
        return jsonify({"success": False, "error": "Request body must be JSON"}), 400

    try:
        user_repository.update_game_stats(g.user_id, game_type, stats)
        return jsonify({"success": True}), 200
    except Exception as e:
        logger.error(f"update_game_stats error: {e}")
        return jsonify({"success": False, "error": "Internal server error"}), 500


# --------------------------------------------------------------------------
# Protected: Wordle Progress (per-date game state)
# --------------------------------------------------------------------------

@users_bp.route("/me/wordle-progress", methods=["PATCH"])
@require_auth
def update_wordle_progress():
    """
    Save or update Wordle progress for a single date.

    Request JSON: {
        "dateKey": "2026-03-02",
        "guesses": ["BRAIN", "SMART"],
        "gameState": "playing"
    }
    """
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"success": False, "error": "Request body must be JSON"}), 400

    date_key = data.get("dateKey", "").strip()
    guesses = data.get("guesses")
    game_state = data.get("gameState", "")

    if not date_key or guesses is None or not game_state:
        return jsonify({"success": False, "error": "dateKey, guesses, and gameState are required"}), 400

    try:
        state = {
            "guesses": guesses,
            "gameState": game_state,
            "dateKey": date_key,
        }
        user_repository.update_wordle_progress(g.user_id, date_key, state)
        return jsonify({"success": True}), 200
    except Exception as e:
        logger.error(f"update_wordle_progress error: {e}")
        return jsonify({"success": False, "error": "Internal server error"}), 500


@users_bp.route("/me/wordle-progress", methods=["GET"])
@require_auth
def get_wordle_progress():
    """Returns all Wordle progress entries for the current user."""
    try:
        progress = user_repository.get_wordle_progress(g.user_id)
        return jsonify({"success": True, "wordleProgress": progress}), 200
    except Exception as e:
        logger.error(f"get_wordle_progress error: {e}")
        return jsonify({"success": False, "error": "Internal server error"}), 500


# --------------------------------------------------------------------------
# Protected: Saved Articles
# --------------------------------------------------------------------------

@users_bp.route("/me/articles/saved", methods=["GET"])
@require_auth
def get_saved_articles():
    try:
        user = user_repository.get_user_by_id(g.user_id)
        if not user:
            return jsonify({"success": False, "error": "User not found"}), 404
        return jsonify({"success": True, "savedArticles": user.get("savedArticles", [])}), 200
    except Exception as e:
        logger.error(f"get_saved_articles error: {e}")
        return jsonify({"success": False, "error": "Internal server error"}), 500


@users_bp.route("/me/articles/saved", methods=["POST"])
@require_auth
def save_article():
    data = request.get_json(silent=True)
    if not data or not data.get("articleId"):
        return jsonify({"success": False, "error": "articleId is required"}), 400

    try:
        user_repository.add_saved_article(g.user_id, data)
        return jsonify({"success": True}), 201
    except Exception as e:
        logger.error(f"save_article error: {e}")
        return jsonify({"success": False, "error": "Internal server error"}), 500


@users_bp.route("/me/articles/saved/<article_id>", methods=["DELETE"])
@require_auth
def unsave_article(article_id: str):
    try:
        user_repository.remove_saved_article(g.user_id, article_id)
        return jsonify({"success": True}), 200
    except Exception as e:
        logger.error(f"unsave_article error: {e}")
        return jsonify({"success": False, "error": "Internal server error"}), 500


# --------------------------------------------------------------------------
# Protected: Read Articles
# --------------------------------------------------------------------------

@users_bp.route("/me/articles/read", methods=["GET"])
@require_auth
def get_read_articles():
    try:
        user = user_repository.get_user_by_id(g.user_id)
        if not user:
            return jsonify({"success": False, "error": "User not found"}), 404
        return jsonify({"success": True, "readArticles": user.get("readArticles", [])}), 200
    except Exception as e:
        logger.error(f"get_read_articles error: {e}")
        return jsonify({"success": False, "error": "Internal server error"}), 500


@users_bp.route("/me/articles/read", methods=["POST"])
@require_auth
def mark_article_read():
    data = request.get_json(silent=True)
    if not data or not data.get("articleId"):
        return jsonify({"success": False, "error": "articleId is required"}), 400

    try:
        user_repository.add_read_article(g.user_id, data["articleId"])
        return jsonify({"success": True}), 201
    except Exception as e:
        logger.error(f"mark_article_read error: {e}")
        return jsonify({"success": False, "error": "Internal server error"}), 500


# --------------------------------------------------------------------------
# Protected: Event RSVPs
# --------------------------------------------------------------------------

@users_bp.route("/me/events", methods=["GET"])
@require_auth
def get_event_rsvps():
    try:
        user = user_repository.get_user_by_id(g.user_id)
        if not user:
            return jsonify({"success": False, "error": "User not found"}), 404
        return jsonify({"success": True, "eventRSVPs": user.get("eventRSVPs", [])}), 200
    except Exception as e:
        logger.error(f"get_event_rsvps error: {e}")
        return jsonify({"success": False, "error": "Internal server error"}), 500


@users_bp.route("/me/events", methods=["POST"])
@require_auth
def rsvp_event():
    data = request.get_json(silent=True)
    if not data or not data.get("eventId") or not data.get("eventTitle"):
        return jsonify({"success": False, "error": "eventId and eventTitle are required"}), 400

    try:
        user_repository.add_event_rsvp(g.user_id, data)
        return jsonify({"success": True}), 201
    except Exception as e:
        logger.error(f"rsvp_event error: {e}")
        return jsonify({"success": False, "error": "Internal server error"}), 500


@users_bp.route("/me/events/<event_id>", methods=["DELETE"])
@require_auth
def cancel_rsvp(event_id: str):
    try:
        user_repository.remove_event_rsvp(g.user_id, event_id)
        return jsonify({"success": True}), 200
    except Exception as e:
        logger.error(f"cancel_rsvp error: {e}")
        return jsonify({"success": False, "error": "Internal server error"}), 500


# --------------------------------------------------------------------------
# Health
# --------------------------------------------------------------------------

@users_bp.route("/health", methods=["GET"])
def health():
    connected = is_firestore_connected()
    return jsonify({
        "status": "healthy" if connected else "degraded",
        "service": "user-profiles",
        "firestore": "connected" if connected else "disconnected",
    }), 200
