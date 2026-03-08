#
#  config.py
#  TapIn Backend — App Configuration API
#
#  Returns client configuration including the minimum required app version.
#  The iOS app checks this on every launch to determine if a force update is needed.
#
#  To force all users to update, set MIN_IOS_VERSION to the latest App Store version.
#

from flask import Blueprint, jsonify

config_bp = Blueprint("config", __name__, url_prefix="/api/config")

# ---------------------------------------------------------------------------
# MARK: - Minimum Version
# ---------------------------------------------------------------------------
# Change this value whenever you publish a new App Store release and want
# all older builds to force-update.  Semantic versioning: "major.minor.patch"
MIN_IOS_VERSION = "1.0.2"

@config_bp.route("/min-version", methods=["GET"])
def min_version():
    """
    Returns the minimum required iOS app version.

    Response:
        {
            "success": true,
            "minVersion": "1.0.2"
        }
    """
    return jsonify({
        "success": True,
        "minVersion": MIN_IOS_VERSION
    })


@config_bp.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok", "service": "config"})
