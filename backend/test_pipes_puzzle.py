#!/usr/bin/env python3
"""
Test script for Pipes puzzle generation and validation.

Run from the tapin-backend directory:
    python test_pipes_puzzle.py
"""

import sys
import os
import json
import random
from datetime import date

# Inline version of PipesPuzzleGenerator for testing without dependencies


class TestPipesPuzzleGenerator:
    """Test version of the puzzle generator without external dependencies."""

    COLORS = ["red", "blue", "green", "yellow", "orange"]

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
        ]

    def _generate_deterministic_puzzle(self, difficulty: str, grid_size: int) -> dict:
        """Generate a puzzle algorithmically without AI."""
        today = date.today()
        seed = today.year * 10000 + today.month * 100 + today.day
        random.seed(seed)

        templates = self._get_puzzle_templates()
        template_idx = seed % len(templates)
        return templates[template_idx]

    def _validate_puzzle(self, puzzle: dict) -> bool:
        """Verify the puzzle is valid and solvable."""
        try:
            size = puzzle.get("size", 5)
            pairs = puzzle.get("pairs", [])
            solution = puzzle.get("solution", [])

            # Must have correct number of pairs
            if len(pairs) != len(self.COLORS):
                print(f"    Warning: Wrong number of pairs: {len(pairs)} != {len(self.COLORS)}")
                return False

            # Check all cells are covered exactly once
            covered = set()
            for path_data in solution:
                for cell in path_data.get("path", []):
                    pos = (cell["row"], cell["col"])

                    # Check bounds
                    if not (0 <= pos[0] < size and 0 <= pos[1] < size):
                        print(f"    Warning: Cell out of bounds: {pos}")
                        return False

                    if pos in covered:
                        print(f"    Warning: Overlap detected at {pos}")
                        return False
                    covered.add(pos)

            expected_cells = size * size
            if len(covered) != expected_cells:
                print(f"    Warning: Not all cells filled: {len(covered)} != {expected_cells}")
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
                    print(f"    Warning: No solution path for color {color}")
                    return False

                path = [(c["row"], c["col"]) for c in solution_path["path"]]

                # Check path connects start and end
                if not ((path[0] == start and path[-1] == end) or
                        (path[0] == end and path[-1] == start)):
                    print(f"    Warning: Path for {color} doesn't connect endpoints")
                    return False

                # Check path is contiguous
                for i in range(len(path) - 1):
                    curr = path[i]
                    next_cell = path[i + 1]
                    dr = abs(curr[0] - next_cell[0])
                    dc = abs(curr[1] - next_cell[1])
                    if not ((dr == 1 and dc == 0) or (dr == 0 and dc == 1)):
                        print(f"    Warning: Path for {color} has non-adjacent cells: {curr} -> {next_cell}")
                        return False

            return True

        except Exception as e:
            print(f"    Warning: Validation error: {e}")
            return False


def test_deterministic_puzzles():
    """Test that deterministic puzzles are valid."""
    print("=" * 60)
    print("Testing Deterministic Puzzle Templates")
    print("=" * 60)

    generator = TestPipesPuzzleGenerator()
    templates = generator._get_puzzle_templates()

    for i, template in enumerate(templates):
        print(f"\nTemplate {i + 1}:")

        is_valid = generator._validate_puzzle(template)

        if is_valid:
            print(f"  ✓ Valid puzzle")
            print(f"    Size: {template['size']}x{template['size']}")
            print(f"    Colors: {[p['color'] for p in template['pairs']]}")

            total_cells = 0
            for path_data in template['solution']:
                path_len = len(path_data['path'])
                total_cells += path_len
                print(f"    {path_data['color']}: {path_len} cells")

            print(f"    Total cells: {total_cells}/{template['size'] * template['size']}")
        else:
            print(f"  ✗ INVALID puzzle!")
            return False

    return True


def test_puzzle_structure():
    """Test the structure of generated puzzles."""
    print("\n" + "=" * 60)
    print("Testing Puzzle Structure")
    print("=" * 60)

    generator = TestPipesPuzzleGenerator()
    puzzle = generator._generate_deterministic_puzzle("medium", 5)

    print(f"\nGenerated puzzle:")
    print(f"  Size: {puzzle['size']}")
    print(f"  Number of pairs: {len(puzzle['pairs'])}")

    for pair in puzzle['pairs']:
        start = pair['start']
        end = pair['end']
        print(f"  {pair['color']}: ({start['row']},{start['col']}) -> ({end['row']},{end['col']})")

    return True


def test_validation_catches_errors():
    """Test that validation catches invalid puzzles."""
    print("\n" + "=" * 60)
    print("Testing Validation Error Detection")
    print("=" * 60)

    generator = TestPipesPuzzleGenerator()

    # Test 1: Overlapping paths
    print("\n  Test: Overlapping paths")
    invalid_overlap = {
        "size": 5,
        "pairs": [
            {"color": "red", "start": {"row": 0, "col": 0}, "end": {"row": 0, "col": 2}},
            {"color": "blue", "start": {"row": 0, "col": 1}, "end": {"row": 0, "col": 3}},
            {"color": "green", "start": {"row": 1, "col": 0}, "end": {"row": 1, "col": 2}},
            {"color": "yellow", "start": {"row": 2, "col": 0}, "end": {"row": 2, "col": 2}},
            {"color": "orange", "start": {"row": 3, "col": 0}, "end": {"row": 3, "col": 2}},
        ],
        "solution": [
            {"color": "red", "path": [{"row": 0, "col": 0}, {"row": 0, "col": 1}, {"row": 0, "col": 2}]},
            {"color": "blue", "path": [{"row": 0, "col": 1}, {"row": 0, "col": 2}, {"row": 0, "col": 3}]},  # Overlaps!
            {"color": "green", "path": [{"row": 1, "col": 0}, {"row": 1, "col": 1}, {"row": 1, "col": 2}]},
            {"color": "yellow", "path": [{"row": 2, "col": 0}, {"row": 2, "col": 1}, {"row": 2, "col": 2}]},
            {"color": "orange", "path": [{"row": 3, "col": 0}, {"row": 3, "col": 1}, {"row": 3, "col": 2}]},
        ]
    }

    if not generator._validate_puzzle(invalid_overlap):
        print("  ✓ Correctly rejected overlapping paths")
    else:
        print("  ✗ Failed to detect overlapping paths")
        return False

    # Test 2: Non-contiguous path
    print("\n  Test: Non-contiguous path")
    invalid_noncontiguous = {
        "size": 5,
        "pairs": [
            {"color": "red", "start": {"row": 0, "col": 0}, "end": {"row": 0, "col": 4}},
            {"color": "blue", "start": {"row": 1, "col": 0}, "end": {"row": 1, "col": 4}},
            {"color": "green", "start": {"row": 2, "col": 0}, "end": {"row": 2, "col": 4}},
            {"color": "yellow", "start": {"row": 3, "col": 0}, "end": {"row": 3, "col": 4}},
            {"color": "orange", "start": {"row": 4, "col": 0}, "end": {"row": 4, "col": 4}},
        ],
        "solution": [
            {"color": "red", "path": [
                {"row": 0, "col": 0},
                {"row": 0, "col": 2},  # Skips col 1
                {"row": 0, "col": 4}
            ]},
            {"color": "blue", "path": [{"row": 1, "col": 0}, {"row": 1, "col": 1}, {"row": 1, "col": 2}, {"row": 1, "col": 3}, {"row": 1, "col": 4}]},
            {"color": "green", "path": [{"row": 2, "col": 0}, {"row": 2, "col": 1}, {"row": 2, "col": 2}, {"row": 2, "col": 3}, {"row": 2, "col": 4}]},
            {"color": "yellow", "path": [{"row": 3, "col": 0}, {"row": 3, "col": 1}, {"row": 3, "col": 2}, {"row": 3, "col": 3}, {"row": 3, "col": 4}]},
            {"color": "orange", "path": [{"row": 4, "col": 0}, {"row": 4, "col": 1}, {"row": 4, "col": 2}, {"row": 4, "col": 3}, {"row": 4, "col": 4}]},
        ]
    }

    if not generator._validate_puzzle(invalid_noncontiguous):
        print("  ✓ Correctly rejected non-contiguous path")
    else:
        print("  ✗ Failed to detect non-contiguous path")
        return False

    return True


def test_api_response_format():
    """Test that the puzzle format matches the API contract."""
    print("\n" + "=" * 60)
    print("Testing API Response Format")
    print("=" * 60)

    generator = TestPipesPuzzleGenerator()
    puzzle = generator._generate_deterministic_puzzle("medium", 5)

    # Check required fields
    required_fields = ["size", "pairs", "solution"]
    for field in required_fields:
        if field not in puzzle:
            print(f"  ✗ Missing required field: {field}")
            return False
        print(f"  ✓ Has required field: {field}")

    # Check pairs format
    for pair in puzzle["pairs"]:
        required_pair_fields = ["color", "start", "end"]
        for field in required_pair_fields:
            if field not in pair:
                print(f"  ✗ Pair missing field: {field}")
                return False

        if "row" not in pair["start"] or "col" not in pair["start"]:
            print("  ✗ Start position missing row/col")
            return False

        if "row" not in pair["end"] or "col" not in pair["end"]:
            print("  ✗ End position missing row/col")
            return False

    print("  ✓ Pairs format is correct")

    # Check solution format
    for path_data in puzzle["solution"]:
        if "color" not in path_data or "path" not in path_data:
            print("  ✗ Solution path missing color or path")
            return False

        for cell in path_data["path"]:
            if "row" not in cell or "col" not in cell:
                print("  ✗ Path cell missing row/col")
                return False

    print("  ✓ Solution format is correct")

    return True


def main():
    """Run all tests."""
    print("\n" + "=" * 60)
    print("PIPES PUZZLE GENERATION TESTS")
    print("=" * 60)

    tests = [
        ("Deterministic Puzzles", test_deterministic_puzzles),
        ("Puzzle Structure", test_puzzle_structure),
        ("Validation Error Detection", test_validation_catches_errors),
        ("API Response Format", test_api_response_format),
    ]

    results = []
    for name, test_fn in tests:
        try:
            passed = test_fn()
            results.append((name, passed))
        except Exception as e:
            print(f"\n  ✗ Exception in {name}: {e}")
            import traceback
            traceback.print_exc()
            results.append((name, False))

    # Print summary
    print("\n" + "=" * 60)
    print("TEST SUMMARY")
    print("=" * 60)

    all_passed = True
    for name, passed in results:
        status = "✓ PASS" if passed else "✗ FAIL"
        print(f"  {status}: {name}")
        if not passed:
            all_passed = False

    print("=" * 60)
    if all_passed:
        print("All tests passed!")
        return 0
    else:
        print("Some tests failed!")
        return 1


if __name__ == "__main__":
    sys.exit(main())
