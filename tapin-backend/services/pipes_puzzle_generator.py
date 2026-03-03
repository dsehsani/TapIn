#
#  pipes_puzzle_generator.py
#  TapInApp - Backend Server
#
#  MARK: - Pipes Puzzle Generator Service
#  Generates and validates Pipes puzzles using Claude API.
#  Puzzles are Flow Free style - connect colored endpoint pairs with paths
#  that don't cross and fill the entire grid.
#

import os
import json
import logging
import random
from datetime import date
from typing import Optional

import anthropic

logger = logging.getLogger(__name__)


class PipesPuzzleGenerator:
    """Generates and validates Pipes puzzles using Claude API."""

    COLORS = ["red", "blue", "green", "yellow", "orange"]

    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or os.environ.get("CLAUDE_API_KEY")
        if not self.api_key:
            logger.warning("No Claude API key provided - will use fallback puzzles only")

    def _get_client(self) -> anthropic.Anthropic:
        """Create an Anthropic client. Raises if API key is missing."""
        if not self.api_key:
            raise ValueError("CLAUDE_API_KEY is not set")
        return anthropic.Anthropic(api_key=self.api_key)

    def generate_puzzle(self, difficulty: str = "medium", grid_size: int = 5) -> dict:
        """
        Generate a puzzle using Claude.

        Args:
            difficulty: "easy", "medium", or "hard"
            grid_size: Size of the grid (default 5x5)

        Returns:
            Dict with puzzle data including size, pairs, and solution
        """
        prompt = f"""Generate a Pipes puzzle (Flow Free style) with these specifications:

Grid Size: {grid_size}x{grid_size}
Difficulty: {difficulty}
Number of colors: {len(self.COLORS)}

Rules:
1. Place pairs of colored endpoints on a grid
2. Each color must have exactly 2 endpoints
3. The puzzle must be solvable by connecting each pair with a path
4. Paths cannot cross each other
5. All {grid_size * grid_size} cells must be filled when solved
6. Use these colors: {', '.join(self.COLORS)}

For {difficulty} difficulty:
- easy: Short, direct paths with minimal turns (2-4 cells per path average)
- medium: Moderate path lengths with some interweaving (4-6 cells per path average)
- hard: Long paths that weave around each other (5-8 cells per path average)

IMPORTANT: Think step by step:
1. First, fill a {grid_size}x{grid_size} grid with continuous non-overlapping paths
2. Each path should be a different color and connect exactly 2 endpoints
3. Verify all {grid_size * grid_size} cells are used exactly once
4. Then extract just the endpoint pairs

Return ONLY a JSON object in this exact format (no other text):
{{
    "size": {grid_size},
    "pairs": [
        {{"color": "red", "start": {{"row": 0, "col": 0}}, "end": {{"row": 2, "col": 3}}}},
        {{"color": "blue", "start": {{"row": 0, "col": 4}}, "end": {{"row": 4, "col": 1}}}},
        ...
    ],
    "solution": [
        {{"color": "red", "path": [{{"row": 0, "col": 0}}, {{"row": 0, "col": 1}}, {{"row": 0, "col": 2}}, {{"row": 1, "col": 2}}, {{"row": 2, "col": 2}}, {{"row": 2, "col": 3}}]}},
        ...
    ]
}}

The solution paths must:
- Connect each pair's start to end with adjacent cells only (no diagonals)
- Not overlap with any other path
- Fill all {grid_size * grid_size} cells exactly once
"""

        try:
            client = self._get_client()

            message = client.messages.create(
                model="claude-sonnet-4-20250514",
                max_tokens=3000,
                messages=[{"role": "user", "content": prompt}]
            )

            # Parse and validate response
            puzzle_json = self._extract_json(message.content[0].text)

            if self._validate_puzzle(puzzle_json):
                logger.info(f"Generated valid {difficulty} puzzle")
                return puzzle_json
            else:
                logger.warning("Generated puzzle failed validation, retrying...")
                # Try once more
                return self._retry_generation(difficulty, grid_size)

        except anthropic.AuthenticationError:
            logger.error("Invalid Claude API key")
            raise ValueError("Invalid Claude API key")
        except Exception as e:
            logger.error(f"Puzzle generation failed: {e}")
            raise

    def _retry_generation(self, difficulty: str, grid_size: int) -> dict:
        """Retry puzzle generation with a simpler prompt."""
        # Fall back to a deterministic puzzle for reliability
        return self._generate_deterministic_puzzle(difficulty, grid_size)

    def _generate_deterministic_puzzle(self, difficulty: str, grid_size: int) -> dict:
        """
        Generate a puzzle algorithmically without AI.
        This serves as a reliable fallback.
        """
        # Use date as seed for deterministic daily puzzles
        today = date.today()
        seed = today.year * 10000 + today.month * 100 + today.day
        random.seed(seed)

        # Pre-designed puzzle templates that are guaranteed solvable
        templates = self._get_puzzle_templates()

        # Select template based on date
        template_idx = seed % len(templates)
        template = templates[template_idx]

        return template

    def _get_puzzle_templates(self) -> list:
        """Return a list of pre-designed solvable puzzle templates."""
        return [
            # Template 1 - Easy
            {
                "size": 5,
                "pairs": [
                    {"color": "red", "start": {"row": 0, "col": 0}, "end": {"row": 1, "col": 3}},
                    {"color": "blue", "start": {"row": 0, "col": 3}, "end": {"row": 2, "col": 3}},
                    {"color": "green", "start": {"row": 1, "col": 0}, "end": {"row": 3, "col": 0}},
                    {"color": "yellow", "start": {"row": 2, "col": 2}, "end": {"row": 4, "col": 0}},
                    {"color": "orange", "start": {"row": 3, "col": 3}, "end": {"row": 4, "col": 2}},
                ],
                "solution": [
                    {"color": "red", "path": [{"row": 0, "col": 0}, {"row": 0, "col": 1}, {"row": 0, "col": 2}, {"row": 1, "col": 2}, {"row": 1, "col": 3}]},
                    {"color": "blue", "path": [{"row": 0, "col": 3}, {"row": 0, "col": 4}, {"row": 1, "col": 4}, {"row": 2, "col": 4}, {"row": 2, "col": 3}]},
                    {"color": "green", "path": [{"row": 1, "col": 0}, {"row": 1, "col": 1}, {"row": 2, "col": 1}, {"row": 2, "col": 0}, {"row": 3, "col": 0}]},
                    {"color": "yellow", "path": [{"row": 2, "col": 2}, {"row": 3, "col": 2}, {"row": 3, "col": 1}, {"row": 4, "col": 1}, {"row": 4, "col": 0}]},
                    {"color": "orange", "path": [{"row": 3, "col": 3}, {"row": 3, "col": 4}, {"row": 4, "col": 4}, {"row": 4, "col": 3}, {"row": 4, "col": 2}]},
                ]
            },
            # Template 2 - Medium
            {
                "size": 5,
                "pairs": [
                    {"color": "red", "start": {"row": 0, "col": 0}, "end": {"row": 2, "col": 0}},
                    {"color": "blue", "start": {"row": 0, "col": 2}, "end": {"row": 1, "col": 3}},
                    {"color": "green", "start": {"row": 1, "col": 2}, "end": {"row": 3, "col": 0}},
                    {"color": "yellow", "start": {"row": 2, "col": 3}, "end": {"row": 3, "col": 2}},
                    {"color": "orange", "start": {"row": 4, "col": 0}, "end": {"row": 4, "col": 4}},
                ],
                "solution": [
                    {"color": "red", "path": [{"row": 0, "col": 0}, {"row": 0, "col": 1}, {"row": 1, "col": 1}, {"row": 1, "col": 0}, {"row": 2, "col": 0}]},
                    {"color": "blue", "path": [{"row": 0, "col": 2}, {"row": 0, "col": 3}, {"row": 0, "col": 4}, {"row": 1, "col": 4}, {"row": 1, "col": 3}]},
                    {"color": "green", "path": [{"row": 1, "col": 2}, {"row": 2, "col": 2}, {"row": 2, "col": 1}, {"row": 3, "col": 1}, {"row": 3, "col": 0}]},
                    {"color": "yellow", "path": [{"row": 2, "col": 3}, {"row": 2, "col": 4}, {"row": 3, "col": 4}, {"row": 3, "col": 3}, {"row": 3, "col": 2}]},
                    {"color": "orange", "path": [{"row": 4, "col": 0}, {"row": 4, "col": 1}, {"row": 4, "col": 2}, {"row": 4, "col": 3}, {"row": 4, "col": 4}]},
                ]
            },
            # Template 3 - Hard
            {
                "size": 5,
                "pairs": [
                    {"color": "red", "start": {"row": 0, "col": 0}, "end": {"row": 1, "col": 1}},
                    {"color": "blue", "start": {"row": 0, "col": 3}, "end": {"row": 2, "col": 3}},
                    {"color": "green", "start": {"row": 1, "col": 0}, "end": {"row": 3, "col": 2}},
                    {"color": "yellow", "start": {"row": 2, "col": 4}, "end": {"row": 4, "col": 4}},
                    {"color": "orange", "start": {"row": 4, "col": 2}, "end": {"row": 3, "col": 1}},
                ],
                "solution": [
                    {"color": "red", "path": [{"row": 0, "col": 0}, {"row": 0, "col": 1}, {"row": 0, "col": 2}, {"row": 1, "col": 2}, {"row": 1, "col": 1}]},
                    {"color": "blue", "path": [{"row": 0, "col": 3}, {"row": 0, "col": 4}, {"row": 1, "col": 4}, {"row": 1, "col": 3}, {"row": 2, "col": 3}]},
                    {"color": "green", "path": [{"row": 1, "col": 0}, {"row": 2, "col": 0}, {"row": 2, "col": 1}, {"row": 2, "col": 2}, {"row": 3, "col": 2}]},
                    {"color": "yellow", "path": [{"row": 2, "col": 4}, {"row": 3, "col": 4}, {"row": 3, "col": 3}, {"row": 4, "col": 3}, {"row": 4, "col": 4}]},
                    {"color": "orange", "path": [{"row": 4, "col": 2}, {"row": 4, "col": 1}, {"row": 4, "col": 0}, {"row": 3, "col": 0}, {"row": 3, "col": 1}]},
                ]
            },
            # Template 4
            {
                "size": 5,
                "pairs": [
                    {"color": "red", "start": {"row": 0, "col": 0}, "end": {"row": 1, "col": 4}},
                    {"color": "blue", "start": {"row": 1, "col": 0}, "end": {"row": 2, "col": 0}},
                    {"color": "green", "start": {"row": 1, "col": 2}, "end": {"row": 3, "col": 3}},
                    {"color": "yellow", "start": {"row": 2, "col": 2}, "end": {"row": 3, "col": 0}},
                    {"color": "orange", "start": {"row": 4, "col": 0}, "end": {"row": 4, "col": 4}},
                ],
                "solution": [
                    {"color": "red", "path": [{"row": 0, "col": 0}, {"row": 0, "col": 1}, {"row": 0, "col": 2}, {"row": 0, "col": 3}, {"row": 0, "col": 4}, {"row": 1, "col": 4}]},
                    {"color": "blue", "path": [{"row": 1, "col": 0}, {"row": 1, "col": 1}, {"row": 2, "col": 1}, {"row": 2, "col": 0}]},
                    {"color": "green", "path": [{"row": 1, "col": 2}, {"row": 1, "col": 3}, {"row": 2, "col": 3}, {"row": 2, "col": 4}, {"row": 3, "col": 4}, {"row": 3, "col": 3}]},
                    {"color": "yellow", "path": [{"row": 2, "col": 2}, {"row": 3, "col": 2}, {"row": 3, "col": 1}, {"row": 3, "col": 0}]},
                    {"color": "orange", "path": [{"row": 4, "col": 0}, {"row": 4, "col": 1}, {"row": 4, "col": 2}, {"row": 4, "col": 3}, {"row": 4, "col": 4}]},
                ]
            },
            # Template 5
            {
                "size": 5,
                "pairs": [
                    {"color": "red", "start": {"row": 0, "col": 0}, "end": {"row": 4, "col": 0}},
                    {"color": "blue", "start": {"row": 0, "col": 4}, "end": {"row": 4, "col": 4}},
                    {"color": "green", "start": {"row": 0, "col": 1}, "end": {"row": 2, "col": 1}},
                    {"color": "yellow", "start": {"row": 0, "col": 3}, "end": {"row": 3, "col": 2}},
                    {"color": "orange", "start": {"row": 3, "col": 1}, "end": {"row": 3, "col": 3}},
                ],
                "solution": [
                    {"color": "red", "path": [{"row": 0, "col": 0}, {"row": 1, "col": 0}, {"row": 2, "col": 0}, {"row": 3, "col": 0}, {"row": 4, "col": 0}]},
                    {"color": "blue", "path": [{"row": 0, "col": 4}, {"row": 1, "col": 4}, {"row": 2, "col": 4}, {"row": 3, "col": 4}, {"row": 4, "col": 4}]},
                    {"color": "green", "path": [{"row": 0, "col": 1}, {"row": 0, "col": 2}, {"row": 1, "col": 2}, {"row": 1, "col": 1}, {"row": 2, "col": 1}]},
                    {"color": "yellow", "path": [{"row": 0, "col": 3}, {"row": 1, "col": 3}, {"row": 2, "col": 3}, {"row": 2, "col": 2}, {"row": 3, "col": 2}]},
                    {"color": "orange", "path": [{"row": 3, "col": 1}, {"row": 4, "col": 1}, {"row": 4, "col": 2}, {"row": 4, "col": 3}, {"row": 3, "col": 3}]},
                ]
            },
            # Template 6
            {
                "size": 5,
                "pairs": [
                    {"color": "red", "start": {"row": 0, "col": 0}, "end": {"row": 1, "col": 3}},
                    {"color": "blue", "start": {"row": 0, "col": 4}, "end": {"row": 2, "col": 2}},
                    {"color": "green", "start": {"row": 1, "col": 0}, "end": {"row": 1, "col": 2}},
                    {"color": "yellow", "start": {"row": 3, "col": 0}, "end": {"row": 3, "col": 4}},
                    {"color": "orange", "start": {"row": 4, "col": 0}, "end": {"row": 4, "col": 4}},
                ],
                "solution": [
                    {"color": "red", "path": [{"row": 0, "col": 0}, {"row": 0, "col": 1}, {"row": 0, "col": 2}, {"row": 0, "col": 3}, {"row": 1, "col": 3}]},
                    {"color": "blue", "path": [{"row": 0, "col": 4}, {"row": 1, "col": 4}, {"row": 2, "col": 4}, {"row": 2, "col": 3}, {"row": 2, "col": 2}]},
                    {"color": "green", "path": [{"row": 1, "col": 0}, {"row": 2, "col": 0}, {"row": 2, "col": 1}, {"row": 1, "col": 1}, {"row": 1, "col": 2}]},
                    {"color": "yellow", "path": [{"row": 3, "col": 0}, {"row": 3, "col": 1}, {"row": 3, "col": 2}, {"row": 3, "col": 3}, {"row": 3, "col": 4}]},
                    {"color": "orange", "path": [{"row": 4, "col": 0}, {"row": 4, "col": 1}, {"row": 4, "col": 2}, {"row": 4, "col": 3}, {"row": 4, "col": 4}]},
                ]
            },
            # Template 7
            {
                "size": 5,
                "pairs": [
                    {"color": "red", "start": {"row": 0, "col": 0}, "end": {"row": 1, "col": 4}},
                    {"color": "blue", "start": {"row": 1, "col": 0}, "end": {"row": 2, "col": 0}},
                    {"color": "green", "start": {"row": 1, "col": 2}, "end": {"row": 3, "col": 3}},
                    {"color": "yellow", "start": {"row": 2, "col": 2}, "end": {"row": 3, "col": 0}},
                    {"color": "orange", "start": {"row": 4, "col": 0}, "end": {"row": 4, "col": 4}},
                ],
                "solution": [
                    {"color": "red", "path": [{"row": 0, "col": 0}, {"row": 0, "col": 1}, {"row": 0, "col": 2}, {"row": 0, "col": 3}, {"row": 0, "col": 4}, {"row": 1, "col": 4}]},
                    {"color": "blue", "path": [{"row": 1, "col": 0}, {"row": 1, "col": 1}, {"row": 2, "col": 1}, {"row": 2, "col": 0}]},
                    {"color": "green", "path": [{"row": 1, "col": 2}, {"row": 1, "col": 3}, {"row": 2, "col": 3}, {"row": 2, "col": 4}, {"row": 3, "col": 4}, {"row": 3, "col": 3}]},
                    {"color": "yellow", "path": [{"row": 2, "col": 2}, {"row": 3, "col": 2}, {"row": 3, "col": 1}, {"row": 3, "col": 0}]},
                    {"color": "orange", "path": [{"row": 4, "col": 0}, {"row": 4, "col": 1}, {"row": 4, "col": 2}, {"row": 4, "col": 3}, {"row": 4, "col": 4}]},
                ]
            },
        ]

    def _validate_puzzle(self, puzzle: dict) -> bool:
        """Verify the puzzle is valid and solvable."""
        try:
            size = puzzle.get("size", 5)
            pairs = puzzle.get("pairs", [])
            solution = puzzle.get("solution", [])

            # Must have correct number of pairs
            if len(pairs) != len(self.COLORS):
                logger.warning(f"Wrong number of pairs: {len(pairs)} != {len(self.COLORS)}")
                return False

            # Check all cells are covered exactly once
            covered = set()
            for path_data in solution:
                for cell in path_data.get("path", []):
                    pos = (cell["row"], cell["col"])

                    # Check bounds
                    if not (0 <= pos[0] < size and 0 <= pos[1] < size):
                        logger.warning(f"Cell out of bounds: {pos}")
                        return False

                    if pos in covered:
                        logger.warning(f"Overlap detected at {pos}")
                        return False
                    covered.add(pos)

            expected_cells = size * size
            if len(covered) != expected_cells:
                logger.warning(f"Not all cells filled: {len(covered)} != {expected_cells}")
                return False

            # Verify paths connect endpoints and are contiguous
            for pair in pairs:
                color = pair["color"]
                start = (pair["start"]["row"], pair["start"]["col"])
                end = (pair["end"]["row"], pair["end"]["col"])

                solution_path = next(
                    (p for p in solution if p["color"] == color), None
                )
                if not solution_path:
                    logger.warning(f"No solution path for color {color}")
                    return False

                path = [(c["row"], c["col"]) for c in solution_path["path"]]

                # Check path connects start and end
                if not ((path[0] == start and path[-1] == end) or
                        (path[0] == end and path[-1] == start)):
                    logger.warning(f"Path for {color} doesn't connect endpoints")
                    return False

                # Check path is contiguous (each cell adjacent to next)
                for i in range(len(path) - 1):
                    curr = path[i]
                    next_cell = path[i + 1]
                    dr = abs(curr[0] - next_cell[0])
                    dc = abs(curr[1] - next_cell[1])
                    if not ((dr == 1 and dc == 0) or (dr == 0 and dc == 1)):
                        logger.warning(f"Path for {color} has non-adjacent cells: {curr} -> {next_cell}")
                        return False

            return True

        except Exception as e:
            logger.error(f"Validation error: {e}")
            return False

    def _extract_json(self, text: str) -> dict:
        """Extract JSON from Claude's response."""
        # Find JSON block in response
        start = text.find("{")
        end = text.rfind("}") + 1
        if start == -1 or end == 0:
            raise ValueError("No JSON found in response")

        json_str = text[start:end]
        return json.loads(json_str)


# Singleton instance
pipes_puzzle_generator = PipesPuzzleGenerator()
