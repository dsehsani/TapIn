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

    def generate_puzzle_set(self, difficulties: list, grid_size: int = 5) -> list:
        """
        Generate multiple puzzles for a daily-five set.
        Guarantees all 5 puzzles are distinct and progressively difficult.

        Tries Claude API first for unique AI-generated puzzles.
        Falls back to difficulty-matched deterministic templates.

        Args:
            difficulties: List of difficulty strings, e.g. ["easy", "easy", "medium", "medium", "hard"]
            grid_size: Size of the grid (default 5x5)

        Returns:
            List of puzzle dicts (without solutions)
        """
        # Try Claude API generation first
        try:
            if self.api_key:
                puzzles = self._generate_ai_puzzle_set(difficulties, grid_size)
                if puzzles and len(puzzles) == len(difficulties):
                    logger.info(f"Generated {len(puzzles)} unique AI puzzles")
                    return puzzles
                logger.warning("AI puzzle set incomplete, falling back to templates")
        except Exception as e:
            logger.warning(f"AI puzzle set generation failed: {e}")

        return self._generate_deterministic_set(difficulties, grid_size)

    # ------------------------------------------------------------------
    # MARK: - AI Puzzle Set Generation
    # ------------------------------------------------------------------

    def _generate_ai_puzzle_set(self, difficulties: list, grid_size: int = 5) -> list:
        """
        Generate all 5 puzzles in a single Claude API call.
        Each puzzle is unique and matched to its difficulty level.
        Validates with backtracking solver to guarantee solvability.
        """
        diff_summary = "\n".join(f"  Puzzle {i+1}: {d}" for i, d in enumerate(difficulties))

        prompt = f"""Generate {len(difficulties)} UNIQUE Pipes puzzles (Flow Free style) for a daily puzzle set.

Grid Size: {grid_size}x{grid_size} for each puzzle
Colors: {', '.join(self.COLORS)} (5 colors per puzzle)

The puzzles must have ESCALATING DIFFICULTY:
{diff_summary}

Difficulty guidelines:
- easy: Short, direct paths with minimal turns. Most paths are 3-5 cells. Endpoints are close together. Few paths cross over each other's natural routes.
- medium: Moderate path lengths (4-6 cells average). Some paths must weave around others. At least 2 paths have 2+ turns.
- hard: Long, winding paths (5-8 cells average). Paths interleave significantly. The solution is not obvious from endpoint positions. Multiple paths must route around each other.

CRITICAL REQUIREMENTS:
1. Each puzzle must be COMPLETELY DIFFERENT - different endpoint positions, different path structures
2. Each color pair must have exactly 2 endpoints
3. All {grid_size * grid_size} cells must be filled when solved (no empty cells)
4. Paths cannot cross or overlap
5. Paths connect only through adjacent cells (up/down/left/right, NO diagonals)
6. Each puzzle must be solvable

Think step by step for EACH puzzle:
1. Design the solution paths first (fill the entire grid with 5 non-overlapping paths)
2. Verify all {grid_size * grid_size} cells are covered exactly once
3. Extract the endpoint pairs from the solution paths

Return ONLY a JSON array with {len(difficulties)} puzzle objects (no other text):
[
    {{
        "index": 0,
        "size": {grid_size},
        "difficulty": "easy",
        "pairs": [
            {{"color": "red", "start": {{"row": 0, "col": 0}}, "end": {{"row": 1, "col": 2}}}},
            ...
        ],
        "solution": [
            {{"color": "red", "path": [{{"row": 0, "col": 0}}, {{"row": 0, "col": 1}}, {{"row": 1, "col": 1}}, {{"row": 1, "col": 2}}]}},
            ...
        ]
    }},
    ...
]
"""

        client = self._get_client()
        message = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=8000,
            messages=[{"role": "user", "content": prompt}]
        )

        response_text = message.content[0].text

        # Extract JSON array
        start = response_text.find("[")
        end = response_text.rfind("]") + 1
        if start == -1 or end == 0:
            raise ValueError("No JSON array found in response")

        puzzle_list = json.loads(response_text[start:end])

        if len(puzzle_list) != len(difficulties):
            raise ValueError(f"Expected {len(difficulties)} puzzles, got {len(puzzle_list)}")

        # Validate each puzzle, retry failures individually
        validated = [None] * len(difficulties)
        seen_endpoint_sets = []
        failed_indices = []

        for i, puzzle in enumerate(puzzle_list):
            puzzle["index"] = i
            puzzle["difficulty"] = difficulties[i]

            failure_reason = self._check_puzzle(puzzle, seen_endpoint_sets)
            if failure_reason:
                logger.warning(f"Puzzle {i} ({difficulties[i]}): {failure_reason}")
                failed_indices.append(i)
                continue

            # Track uniqueness
            endpoint_set = frozenset(
                (p["color"], p["start"]["row"], p["start"]["col"], p["end"]["row"], p["end"]["col"])
                for p in puzzle["pairs"]
            )
            seen_endpoint_sets.append(endpoint_set)

            validated[i] = {
                "index": i,
                "size": puzzle["size"],
                "pairs": puzzle["pairs"],
                "difficulty": difficulties[i],
            }

        # Retry failed puzzles with solver feedback (one API call for all failures)
        if failed_indices:
            logger.info(f"Retrying {len(failed_indices)} failed puzzles with feedback")
            replacements = self._retry_failed_puzzles(
                failed_indices, difficulties, grid_size, puzzle_list, seen_endpoint_sets
            )
            for idx, replacement in zip(failed_indices, replacements):
                if replacement:
                    validated[idx] = replacement

        # Fill any still-missing puzzles with templates
        for i in range(len(validated)):
            if validated[i] is None:
                logger.warning(f"Puzzle {i} still failed after retry, using template fallback")
                templates = self._get_templates_by_difficulty()
                pool = templates.get(difficulties[i], self._get_puzzle_templates())
                fallback = pool[i % len(pool)]
                validated[i] = {
                    "index": i,
                    "size": fallback["size"],
                    "pairs": fallback["pairs"],
                    "difficulty": difficulties[i],
                }

        return validated

    def _check_puzzle(self, puzzle: dict, seen_endpoint_sets: list) -> Optional[str]:
        """
        Validate a puzzle and return failure reason, or None if valid.
        """
        if not self._validate_puzzle(puzzle):
            return "failed structural validation"

        if not self._solve_puzzle(puzzle):
            return "failed solvability check"

        endpoint_set = frozenset(
            (p["color"], p["start"]["row"], p["start"]["col"], p["end"]["row"], p["end"]["col"])
            for p in puzzle["pairs"]
        )
        if endpoint_set in seen_endpoint_sets:
            return "duplicate of another puzzle"

        return None

    def _retry_failed_puzzles(
        self, failed_indices: list, difficulties: list,
        grid_size: int, original_puzzles: list, seen_endpoint_sets: list
    ) -> list:
        """
        Retry failed puzzles with a single API call that includes
        solver feedback explaining what went wrong.
        """
        retry_descriptions = []
        for idx in failed_indices:
            original = original_puzzles[idx]
            reason = self._check_puzzle(original, seen_endpoint_sets)
            retry_descriptions.append(
                f"Puzzle {idx + 1} ({difficulties[idx]}): {reason}. "
                f"Original pairs: {json.dumps(original.get('pairs', []))}"
            )

        feedback = "\n".join(retry_descriptions)
        prompt = f"""The following Pipes puzzles from a daily set failed validation. Generate REPLACEMENTS.

FAILURES:
{feedback}

Generate {len(failed_indices)} NEW replacement puzzles. Each must be:
- A {grid_size}x{grid_size} grid using colors: {', '.join(self.COLORS)}
- COMPLETELY DIFFERENT from the failed versions (different endpoint positions)
- Solvable: all {grid_size * grid_size} cells filled with non-overlapping adjacent paths

Difficulties needed: {', '.join(difficulties[i] for i in failed_indices)}

Difficulty guidelines:
- easy: Short, direct paths (3-5 cells each). Endpoints close together.
- medium: Moderate paths (4-6 cells). Some weaving required.
- hard: Long winding paths (5-8 cells). Paths interleave significantly.

IMPORTANT: Design the solution paths FIRST, verify all {grid_size * grid_size} cells are covered, then extract endpoints.

Return ONLY a JSON array (no other text):
[
    {{
        "size": {grid_size},
        "pairs": [{{"color": "red", "start": {{"row": 0, "col": 0}}, "end": {{"row": 1, "col": 2}}}}, ...],
        "solution": [{{"color": "red", "path": [{{"row": 0, "col": 0}}, ...]}}, ...]
    }},
    ...
]
"""

        try:
            client = self._get_client()
            message = client.messages.create(
                model="claude-sonnet-4-20250514",
                max_tokens=4000,
                messages=[{"role": "user", "content": prompt}]
            )

            response_text = message.content[0].text
            start = response_text.find("[")
            end = response_text.rfind("]") + 1
            if start == -1 or end == 0:
                return [None] * len(failed_indices)

            retry_list = json.loads(response_text[start:end])

            results = []
            for j, puzzle in enumerate(retry_list):
                idx = failed_indices[j] if j < len(failed_indices) else j
                puzzle["index"] = idx
                puzzle["difficulty"] = difficulties[idx]

                failure_reason = self._check_puzzle(puzzle, seen_endpoint_sets)
                if failure_reason:
                    logger.warning(f"Retry puzzle {idx} still failed: {failure_reason}")
                    results.append(None)
                    continue

                endpoint_set = frozenset(
                    (p["color"], p["start"]["row"], p["start"]["col"], p["end"]["row"], p["end"]["col"])
                    for p in puzzle["pairs"]
                )
                seen_endpoint_sets.append(endpoint_set)

                results.append({
                    "index": idx,
                    "size": puzzle["size"],
                    "pairs": puzzle["pairs"],
                    "difficulty": difficulties[idx],
                })

            return results

        except Exception as e:
            logger.error(f"Retry generation failed: {e}")
            return [None] * len(failed_indices)

    # ------------------------------------------------------------------
    # MARK: - Backtracking Solver
    # ------------------------------------------------------------------

    def _solve_puzzle(self, puzzle: dict) -> bool:
        """
        Verify a puzzle is solvable using backtracking DFS.
        Takes only the endpoint pairs and confirms at least one valid
        solution exists that fills the entire grid.

        Returns True if solvable, False otherwise.
        """
        size = puzzle.get("size", 5)
        pairs = puzzle.get("pairs", [])

        # Build list of (color, start, end) tuples
        color_pairs = []
        for pair in pairs:
            start = (pair["start"]["row"], pair["start"]["col"])
            end = (pair["end"]["row"], pair["end"]["col"])
            color_pairs.append((pair["color"], start, end))

        total_cells = size * size
        # Grid tracks which color occupies each cell (None = empty)
        grid = [[None] * size for _ in range(size)]

        # Mark all endpoints on the grid
        for color, start, end in color_pairs:
            grid[start[0]][start[1]] = color
            grid[end[0]][end[1]] = color

        filled_count = len(color_pairs) * 2  # endpoints are pre-filled

        def neighbors(r, c):
            for dr, dc in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                nr, nc = r + dr, c + dc
                if 0 <= nr < size and 0 <= nc < size:
                    yield nr, nc

        def solve(color_idx, pos, filled):
            """Try to extend the path for color_pairs[color_idx] from pos to its end."""
            if color_idx >= len(color_pairs):
                # All colors connected — check if grid is full
                return filled == total_cells

            color, start, end = color_pairs[color_idx]

            # If we've reached the endpoint for this color, move to next color
            if pos == end:
                return solve(color_idx + 1, color_pairs[color_idx + 1][1] if color_idx + 1 < len(color_pairs) else None, filled)

            # Try extending to each neighbor
            for nr, nc in neighbors(pos[0], pos[1]):
                if (nr, nc) == end:
                    # Reached the endpoint — move to next color
                    if solve(color_idx + 1,
                             color_pairs[color_idx + 1][1] if color_idx + 1 < len(color_pairs) else None,
                             filled):
                        return True
                elif grid[nr][nc] is None:
                    grid[nr][nc] = color
                    if solve(color_idx, (nr, nc), filled + 1):
                        return True
                    grid[nr][nc] = None

            return False

        # Start solving from the first color's start position
        try:
            return solve(0, color_pairs[0][1], filled_count)
        except RecursionError:
            logger.warning("Solver hit recursion limit")
            return False

    # ------------------------------------------------------------------
    # MARK: - Deterministic Fallback
    # ------------------------------------------------------------------

    def _generate_deterministic_set(self, difficulties: list, grid_size: int = 5) -> list:
        """
        Pick distinct templates deterministically based on today's date.
        Templates are matched by difficulty level to ensure proper progression.
        """
        today = date.today()
        seed = today.year * 10000 + today.month * 100 + today.day
        rng = random.Random(seed)

        templates_by_difficulty = self._get_templates_by_difficulty()

        # Shuffle each difficulty pool independently
        for diff in templates_by_difficulty:
            rng.shuffle(templates_by_difficulty[diff])

        # Track how many we've used from each difficulty pool
        pick_count = {"easy": 0, "medium": 0, "hard": 0}

        puzzles = []
        seen_indices = set()

        for i, difficulty in enumerate(difficulties):
            pool = templates_by_difficulty.get(difficulty, [])
            idx = pick_count[difficulty] % len(pool) if pool else 0

            template = pool[idx]
            pick_count[difficulty] += 1

            # Ensure no duplicate template across the entire set
            template_id = id(template)
            if template_id in seen_indices and len(pool) > pick_count[difficulty]:
                # Try next in pool
                pick_count[difficulty] += 1
                idx = pick_count[difficulty] % len(pool)
                template = pool[idx]
                template_id = id(template)

            seen_indices.add(template_id)

            puzzles.append({
                "index": i,
                "size": template["size"],
                "pairs": template["pairs"],
                "difficulty": difficulty,
            })

        return puzzles

    def _generate_deterministic_puzzle(self, difficulty: str, grid_size: int, seed_offset: int = 0) -> dict:
        """
        Generate a single puzzle algorithmically without AI.
        This serves as a reliable fallback for the legacy /daily endpoint.
        """
        today = date.today()
        seed = today.year * 10000 + today.month * 100 + today.day + seed_offset * 97
        rng = random.Random(seed)

        templates_by_difficulty = self._get_templates_by_difficulty()
        pool = templates_by_difficulty.get(difficulty, self._get_puzzle_templates())
        rng.shuffle(pool)

        return pool[0]

    def _get_templates_by_difficulty(self) -> dict:
        """Return templates organized by difficulty level."""
        templates = self._get_puzzle_templates()
        by_difficulty = {"easy": [], "medium": [], "hard": []}
        for t in templates:
            diff = t.get("difficulty", "medium")
            by_difficulty[diff].append(t)
        return by_difficulty

    def _get_puzzle_templates(self) -> list:
        """Return a list of pre-designed solvable puzzle templates, tagged by difficulty."""
        return [
            # ---------- EASY templates ----------
            # Template 1 - Easy: mostly straight paths, endpoints close together
            {
                "size": 5,
                "difficulty": "easy",
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
            # Template 2 - Easy: parallel straight paths
            {
                "size": 5,
                "difficulty": "easy",
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
            # Template 3 - Easy: simple L-shaped paths
            {
                "size": 5,
                "difficulty": "easy",
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
            # ---------- MEDIUM templates ----------
            # Template 4 - Medium: some weaving required
            {
                "size": 5,
                "difficulty": "medium",
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
            # Template 5 - Medium: paths cross over natural routes
            {
                "size": 5,
                "difficulty": "medium",
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
            # ---------- HARD templates ----------
            # Template 6 - Hard: long winding paths
            {
                "size": 5,
                "difficulty": "hard",
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
        ]

    # ------------------------------------------------------------------
    # MARK: - Validation
    # ------------------------------------------------------------------

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
