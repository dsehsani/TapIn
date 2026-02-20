#
#  auth_service.py
#  TapInApp - Backend Server
#
#  MARK: - Authentication Service
#  Handles password hashing (bcrypt) and JWT session tokens.
#
#  Environment variables:
#    SECRET_KEY — signing key for JWT tokens (required in production)
#

import os
import logging
from datetime import datetime, timezone, timedelta
from typing import Optional

logger = logging.getLogger(__name__)

# JWT token lifetime
_TOKEN_EXPIRY_DAYS = 7

# Algorithm used for JWT signing
_JWT_ALGORITHM = "HS256"


def _secret_key() -> str:
    """Returns the JWT signing key from the environment."""
    key = os.environ.get("SECRET_KEY", "dev-secret-change-in-production")
    if key == "dev-secret-change-in-production":
        logger.warning("SECRET_KEY is not set — using insecure default (dev only)")
    return key


# ------------------------------------------------------------------------------
# MARK: - Password Hashing
# ------------------------------------------------------------------------------

def hash_password(plain: str) -> str:
    """
    Returns a bcrypt hash of the given plaintext password.
    Always generates a fresh salt — never reuse hashes across users.
    """
    import bcrypt  # lazy — avoid loading at module level
    return bcrypt.hashpw(plain.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(plain: str, hashed: str) -> bool:
    """
    Returns True if `plain` matches the stored bcrypt hash.
    Safe against timing attacks via bcrypt's constant-time comparison.
    """
    import bcrypt  # lazy
    try:
        return bcrypt.checkpw(plain.encode("utf-8"), hashed.encode("utf-8"))
    except Exception as e:
        logger.error(f"Password verification error: {e}")
        return False


# ------------------------------------------------------------------------------
# MARK: - JWT Tokens
# ------------------------------------------------------------------------------

def create_token(user_id: str) -> str:
    """
    Creates a signed JWT for the given user_id.
    Token expires after TOKEN_EXPIRY_DAYS days.
    Payload: { "sub": user_id, "iat": ..., "exp": ... }
    """
    import jwt  # lazy — PyJWT

    now = datetime.now(tz=timezone.utc)
    payload = {
        "sub": user_id,
        "iat": now,
        "exp": now + timedelta(days=_TOKEN_EXPIRY_DAYS),
    }
    return jwt.encode(payload, _secret_key(), algorithm=_JWT_ALGORITHM)


def decode_token(token: str) -> str:
    """
    Decodes a JWT and returns the user_id (subject).
    Raises ValueError on invalid, expired, or tampered tokens.
    """
    import jwt  # lazy — PyJWT

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
