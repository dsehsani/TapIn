#
#  auth_middleware.py
#  TapInApp - Backend Server
#
#  MARK: - JWT Auth Decorator
#  Provides the @require_auth decorator used by protected API endpoints.
#  Validates the Authorization: Bearer <token> header and injects
#  the authenticated user_id into flask.g for use by the route handler.
#

import logging
from functools import wraps
from flask import request, jsonify, g
from services.auth_service import decode_token

logger = logging.getLogger(__name__)


def require_auth(f):
    """
    Decorator that enforces JWT authentication on a route.

    On success: sets g.user_id and calls the wrapped route handler.
    On failure: returns 401 JSON without calling the handler.

    Usage:
        @users_bp.route("/me")
        @require_auth
        def get_me():
            user = user_repository.get_user_by_id(g.user_id)
            ...
    """
    @wraps(f)
    def decorated(*args, **kwargs):
        auth_header = request.headers.get("Authorization", "")
        if not auth_header.startswith("Bearer "):
            return jsonify({
                "success": False,
                "error": "Missing or malformed Authorization header"
            }), 401

        token = auth_header[len("Bearer "):]
        try:
            g.user_id = decode_token(token)
        except ValueError as e:
            return jsonify({
                "success": False,
                "error": str(e)
            }), 401

        return f(*args, **kwargs)

    return decorated
