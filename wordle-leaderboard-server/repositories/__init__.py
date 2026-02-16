#
#  repositories/__init__.py
#  TapInApp - Wordle Leaderboard Server
#
#  Repository layer for data access abstraction.
#

from .score_repository import ScoreRepository, score_repository

__all__ = ["ScoreRepository", "score_repository"]
