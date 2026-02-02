#
#  models.py
#  TapInApp - Wordle Leaderboard Server
#
#  Created by Darius Ehsani on 2/2/26.
#
#  MARK: - Data Models
#  This file contains the data models for the leaderboard system.
#  All models use dataclasses for clean, type-safe data structures.
#
#  Models:
#  - Score: Represents a single player's score submission
#  - LeaderboardEntry: Represents a formatted leaderboard entry for display
#

from dataclasses import dataclass, field
from datetime import date
from typing import Optional
import uuid


# ------------------------------------------------------------------------------
# MARK: - Score Model
# ------------------------------------------------------------------------------

@dataclass
class Score:
    """
    Represents a player's score for a Wordle game.

    Attributes:
        id: Unique identifier for this score entry
        username: Auto-generated username (Adjective+Noun format)
        guesses: Number of guesses taken (1-6)
        time_seconds: Time taken to complete the puzzle in seconds
        puzzle_date: The date of the Wordle puzzle (YYYY-MM-DD)
        created_at: Timestamp when the score was submitted

    Usage:
        score = Score(
            username="SwiftFalcon",
            guesses=4,
            time_seconds=120,
            puzzle_date="2026-02-02"
        )
    """
    username: str
    guesses: int
    time_seconds: int
    puzzle_date: str
    id: str = field(default_factory=lambda: str(uuid.uuid4()))

    def to_dict(self) -> dict:
        """
        Converts the Score to a dictionary for JSON serialization.

        Returns:
            Dictionary representation of the score
        """
        return {
            "id": self.id,
            "username": self.username,
            "guesses": self.guesses,
            "time_seconds": self.time_seconds,
            "puzzle_date": self.puzzle_date
        }

    @classmethod
    def from_dict(cls, data: dict) -> "Score":
        """
        Creates a Score instance from a dictionary.

        Args:
            data: Dictionary containing score data

        Returns:
            Score instance
        """
        return cls(
            id=data.get("id", str(uuid.uuid4())),
            username=data["username"],
            guesses=data["guesses"],
            time_seconds=data["time_seconds"],
            puzzle_date=data["puzzle_date"]
        )


# ------------------------------------------------------------------------------
# MARK: - LeaderboardEntry Model
# ------------------------------------------------------------------------------

@dataclass
class LeaderboardEntry:
    """
    Represents a formatted leaderboard entry for display.

    This is the format returned by the GET leaderboard endpoint.
    Includes rank and emoji representation of guesses.

    Attributes:
        rank: Player's position on the leaderboard (1-5)
        username: Player's auto-generated username
        guesses: Number of guesses taken (1-6)
        guesses_display: Visual representation using green block emojis
        time_seconds: Time taken to complete the puzzle

    Usage:
        entry = LeaderboardEntry(
            rank=1,
            username="SwiftFalcon",
            guesses=3,
            guesses_display="🟩🟩🟩",
            time_seconds=95
        )
    """
    rank: int
    username: str
    guesses: int
    guesses_display: str
    time_seconds: int

    def to_dict(self) -> dict:
        """
        Converts the LeaderboardEntry to a dictionary for JSON serialization.

        Returns:
            Dictionary representation of the leaderboard entry
        """
        return {
            "rank": self.rank,
            "username": self.username,
            "guesses": self.guesses,
            "guesses_display": self.guesses_display,
            "time_seconds": self.time_seconds
        }
