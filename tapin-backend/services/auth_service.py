#
#  auth_service.py
#  TapIn Backend
#
#  Handles JWT tokens, password hashing, and social auth token verification.
#
#  Supported auth providers:
#    - Apple Sign-In (verifies identity token via Apple JWKS)
#    - Google Sign-In (verifies ID token via Google JWKS)
#    - Phone (verifies via external SMS auth service)
#    - Email/Password (bcrypt hashing)
#

import os
import logging
import requests as http_requests
from datetime import datetime, timezone, timedelta
from typing import Optional

logger = logging.getLogger(__name__)

_TOKEN_EXPIRY_DAYS = 30
_JWT_ALGORITHM = "HS256"

# Firebase Admin SDK — initialized lazily for phone auth token verification.
# On Cloud Run with default credentials, no service account JSON is needed.
_firebase_app = None


def _ensure_firebase_initialized():
    """Initialize Firebase Admin SDK if not already done."""
    global _firebase_app
    if _firebase_app is not None:
        return
    import firebase_admin
    from firebase_admin import credentials

    # Use Application Default Credentials (works automatically on Cloud Run / GCP).
    # Locally, set GOOGLE_APPLICATION_CREDENTIALS env var to a service account JSON.
    try:
        _firebase_app = firebase_admin.get_app()
    except ValueError:
        _firebase_app = firebase_admin.initialize_app()


def _secret_key() -> str:
    key = os.environ.get("SECRET_KEY", "dev-secret-change-in-production")
    if key == "dev-secret-change-in-production":
        logger.warning("SECRET_KEY not set — using insecure default (dev only)")
    return key


# --------------------------------------------------------------------------
# Password Hashing
# --------------------------------------------------------------------------

def hash_password(plain: str) -> str:
    import bcrypt
    return bcrypt.hashpw(plain.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(plain: str, hashed: str) -> bool:
    import bcrypt
    try:
        return bcrypt.checkpw(plain.encode("utf-8"), hashed.encode("utf-8"))
    except Exception as e:
        logger.error(f"Password verification error: {e}")
        return False


# --------------------------------------------------------------------------
# JWT Tokens
# --------------------------------------------------------------------------

def create_token(user_id: str) -> str:
    import jwt
    now = datetime.now(tz=timezone.utc)
    payload = {
        "sub": user_id,
        "iat": now,
        "exp": now + timedelta(days=_TOKEN_EXPIRY_DAYS),
    }
    return jwt.encode(payload, _secret_key(), algorithm=_JWT_ALGORITHM)


def decode_token(token: str) -> str:
    import jwt
    try:
        payload = jwt.decode(token, _secret_key(), algorithms=[_JWT_ALGORITHM])
        user_id = payload.get("sub")
        if not user_id:
            raise ValueError("Token missing subject claim")
        return user_id
    except jwt.ExpiredSignatureError:
        raise ValueError("Token has expired")
    except jwt.InvalidTokenError as e:
        raise ValueError(f"Invalid token: {e}")


# --------------------------------------------------------------------------
# Apple Sign-In Verification
# --------------------------------------------------------------------------

_apple_keys_cache = None
_apple_keys_fetched_at = None


def _get_apple_public_keys():
    """Fetch Apple's JWKS public keys (cached for 24h)."""
    global _apple_keys_cache, _apple_keys_fetched_at
    import jwt

    now = datetime.now(tz=timezone.utc)
    if _apple_keys_cache and _apple_keys_fetched_at:
        age = (now - _apple_keys_fetched_at).total_seconds()
        if age < 86400:  # 24 hours
            return _apple_keys_cache

    try:
        resp = http_requests.get("https://appleid.apple.com/auth/keys", timeout=10)
        resp.raise_for_status()
        jwks = resp.json()
        _apple_keys_cache = {
            k["kid"]: jwt.algorithms.RSAAlgorithm.from_jwk(k)
            for k in jwks.get("keys", [])
        }
        _apple_keys_fetched_at = now
        return _apple_keys_cache
    except Exception as e:
        logger.error(f"Failed to fetch Apple JWKS: {e}")
        return _apple_keys_cache or {}


def _invalidate_apple_keys_cache():
    global _apple_keys_cache, _apple_keys_fetched_at
    _apple_keys_cache = None
    _apple_keys_fetched_at = None


def verify_apple_token(identity_token: str) -> dict:
    """
    Verifies an Apple identity token and returns decoded claims.
    Returns dict with 'sub' (Apple user ID), 'email', etc.
    Raises ValueError on invalid token.
    """
    import jwt

    try:
        # Decode header to get kid
        header = jwt.get_unverified_header(identity_token)
        kid = header.get("kid")

        keys = _get_apple_public_keys()
        if not keys:
            raise ValueError("Could not fetch Apple public keys")

        public_key = keys.get(kid)
        if not public_key:
            # Key not in cache — Apple may have rotated keys; force refresh
            _invalidate_apple_keys_cache()
            keys = _get_apple_public_keys()
            public_key = keys.get(kid)
            if not public_key:
                raise ValueError(f"Apple key with kid '{kid}' not found")

        claims = jwt.decode(
            identity_token,
            public_key,
            algorithms=["RS256"],
            audience=os.environ.get("APPLE_BUNDLE_ID", "DariusEhsani.TapInApp"),
            issuer="https://appleid.apple.com",
        )
        return claims

    except jwt.ExpiredSignatureError:
        raise ValueError("Apple identity token has expired")
    except jwt.InvalidTokenError as e:
        raise ValueError(f"Invalid Apple identity token: {e}")
    except Exception as e:
        raise ValueError(f"Apple token verification failed: {e}")


# --------------------------------------------------------------------------
# Google Sign-In Verification
# --------------------------------------------------------------------------

_google_keys_cache = None
_google_keys_fetched_at = None


def _get_google_public_keys():
    """Fetch Google's JWKS public keys (cached for 24h)."""
    global _google_keys_cache, _google_keys_fetched_at
    import jwt

    now = datetime.now(tz=timezone.utc)
    if _google_keys_cache and _google_keys_fetched_at:
        age = (now - _google_keys_fetched_at).total_seconds()
        if age < 86400:  # 24 hours
            return _google_keys_cache

    try:
        resp = http_requests.get("https://www.googleapis.com/oauth2/v3/certs", timeout=10)
        resp.raise_for_status()
        jwks = resp.json()
        _google_keys_cache = {
            k["kid"]: jwt.algorithms.RSAAlgorithm.from_jwk(k)
            for k in jwks.get("keys", [])
        }
        _google_keys_fetched_at = now
        return _google_keys_cache
    except Exception as e:
        logger.error(f"Failed to fetch Google JWKS: {e}")
        return _google_keys_cache or {}


def _invalidate_google_keys_cache():
    global _google_keys_cache, _google_keys_fetched_at
    _google_keys_cache = None
    _google_keys_fetched_at = None


def verify_google_token(id_token: str) -> dict:
    """
    Verifies a Google ID token and returns decoded claims.
    Returns dict with 'sub' (Google user ID), 'email', 'name', etc.
    Raises ValueError on invalid token.
    """
    import jwt

    try:
        header = jwt.get_unverified_header(id_token)
        kid = header.get("kid")

        keys = _get_google_public_keys()
        if not keys:
            raise ValueError("Could not fetch Google public keys")

        public_key = keys.get(kid)
        if not public_key:
            # Key not in cache — Google may have rotated keys; force refresh
            _invalidate_google_keys_cache()
            keys = _get_google_public_keys()
            public_key = keys.get(kid)
            if not public_key:
                raise ValueError(f"Google key with kid '{kid}' not found")

        # Accept both iOS client ID and web client ID as valid audiences
        google_client_id = os.environ.get("GOOGLE_CLIENT_ID", "")
        google_ios_client_id = os.environ.get("GOOGLE_IOS_CLIENT_ID", "")
        valid_audiences = [a for a in [google_client_id, google_ios_client_id] if a]

        if not valid_audiences:
            raise ValueError("GOOGLE_CLIENT_ID not configured on server")

        claims = jwt.decode(
            id_token,
            public_key,
            algorithms=["RS256"],
            audience=valid_audiences,
            issuer=["https://accounts.google.com", "accounts.google.com"],
        )
        return claims

    except jwt.ExpiredSignatureError:
        raise ValueError("Google ID token has expired")
    except jwt.InvalidTokenError as e:
        raise ValueError(f"Invalid Google ID token: {e}")
    except Exception as e:
        raise ValueError(f"Google token verification failed: {e}")


# --------------------------------------------------------------------------
# Phone Auth Verification
# --------------------------------------------------------------------------

def verify_phone_token(firebase_id_token: str) -> dict:
    """
    Verifies a Firebase ID token from Phone Auth.
    Returns dict with 'phone_number' and 'user_id' (Firebase UID).
    Raises ValueError if the token is invalid.
    """
    from firebase_admin import auth as firebase_auth

    _ensure_firebase_initialized()

    try:
        decoded = firebase_auth.verify_id_token(firebase_id_token)

        phone = decoded.get("phone_number", "")
        uid = decoded.get("uid", "")

        if not phone:
            raise ValueError("Firebase token does not contain a phone number")

        return {
            "phone_number": phone,
            "user_id": uid,
        }
    except firebase_auth.InvalidIdTokenError:
        raise ValueError("Invalid Firebase ID token")
    except firebase_auth.ExpiredIdTokenError:
        raise ValueError("Firebase ID token has expired")
    except firebase_auth.RevokedIdTokenError:
        raise ValueError("Firebase ID token has been revoked")
    except ValueError:
        raise
    except Exception as e:
        raise ValueError(f"Phone token verification failed: {e}")
