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
#  - Score: Represents a single player's score submission (Wordle legacy)
#  - LeaderboardEntry: Represents a formatted leaderboard entry for display
#  - GameScore: Unified score model for all game types
#  - UnifiedLeaderboardEntry: Unified leaderboard entry for all games
#

from dataclasses import dataclass, field
from datetime import date
from typing import Optional, Dict, Any
import uuid


# ------------------------------------------------------------------------------
# MARK: - Game Types
# ------------------------------------------------------------------------------

VALID_GAME_TYPES = ["wordle", "echo", "crossword", "trivia"]


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


# ------------------------------------------------------------------------------
# MARK: - Unified GameScore Model
# ------------------------------------------------------------------------------

@dataclass
class GameScore:
    """
    Unified score model for all game types.

    Attributes:
        id: Unique identifier for this score entry
        game_type: Type of game (wordle, echo, crossword, trivia)
        username: Player's username
        score: Computed score value (game-specific)
        date: The date of the puzzle/game (YYYY-MM-DD)
        metadata: Game-specific additional data
    """
    game_type: str
    username: str
    score: int
    date: str
    metadata: Dict[str, Any] = field(default_factory=dict)
    id: str = field(default_factory=lambda: str(uuid.uuid4()))

    def to_dict(self) -> dict:
        """Converts to dictionary for JSON serialization."""
        return {
            "id": self.id,
            "game_type": self.game_type,
            "username": self.username,
            "score": self.score,
            "date": self.date,
            "metadata": self.metadata
        }

    @classmethod
    def from_dict(cls, data: dict) -> "GameScore":
        """Creates a GameScore instance from a dictionary."""
        return cls(
            id=data.get("id", str(uuid.uuid4())),
            game_type=data["game_type"],
            username=data.get("username", ""),
            score=data.get("score", 0),
            date=data["date"],
            metadata=data.get("metadata", {})
        )

    def ranks_higher_than(self, other: "GameScore") -> bool:
        """
        Compares two scores for ranking.
        Returns True if self should rank higher than other.
        """
        if self.game_type != other.game_type:
            return False

        if self.game_type == "wordle":
            # Fewer guesses = better, then faster time
            self_guesses = int(self.metadata.get("guesses", 999))
            other_guesses = int(other.metadata.get("guesses", 999))
            if self_guesses != other_guesses:
                return self_guesses < other_guesses
            self_time = int(self.metadata.get("time_seconds", 999999))
            other_time = int(other.metadata.get("time_seconds", 999999))
            return self_time < other_time

        elif self.game_type == "echo":
            # Higher score = better
            return self.score > other.score

        elif self.game_type == "crossword":
            # Faster time = better
            self_time = int(self.metadata.get("completion_time_seconds", 999999))
            other_time = int(other.metadata.get("completion_time_seconds", 999999))
            return self_time < other_time

        elif self.game_type == "trivia":
            # Higher score = better
            return self.score > other.score

        return False


# ------------------------------------------------------------------------------
# MARK: - Unified LeaderboardEntry Model
# ------------------------------------------------------------------------------

@dataclass
class UnifiedLeaderboardEntry:
    """
    Unified leaderboard entry for all game types.
    """
    id: str
    rank: int
    username: str
    score: int
    game_type: str
    date: str
    metadata: Dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict:
        """Converts to dictionary for JSON serialization."""
        return {
            "id": self.id,
            "rank": self.rank,
            "username": self.username,
            "score": self.score,
            "game_type": self.game_type,
            "date": self.date,
            "metadata": self.metadata
        }
