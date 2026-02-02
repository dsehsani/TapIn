#
#  __init__.py
#  TapInApp - Wordle Leaderboard Server
#
#  Created by Darius Ehsani on 2/2/26.
#
#  MARK: - API Package
#  This package contains the Flask Blueprint for API endpoints.
#

from .leaderboard import leaderboard_bp

__all__ = ["leaderboard_bp"]
