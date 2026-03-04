#
#  auth_middleware.py
#  TapIn Backend
#
#  JWT Auth Decorator — validates Authorization: Bearer <token> header
#  and injects g.user_id for route handlers.
#

import logging
from functools import wraps
from flask import request, jsonify, g
from services.auth_service import decode_token

logger = logging.getLogger(__name__)


def require_auth(f):
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
            return jsonify({"success": False, "error": str(e)}), 401

        return f(*args, **kwargs)

    return decorated
