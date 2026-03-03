# Pipes Game Enhancement Prompt

## Overview

This document outlines the implementation details for two major enhancements to the Pipes game:

1. **Flowing Line Animation** - Replace static cell-by-cell path drawing with smooth, animated flowing lines
2. **Claude-Generated Daily Puzzles** - Use AI to generate unique, solvable puzzles each day

---

## Current Implementation Summary

### File Structure
```
TapInApp/TapInApp/Games/Pipes/
├── Data/
│   └── PipeLevels.swift          # 7 hardcoded puzzles
├── Models/
│   └── PipesModels.swift         # PipePosition, PipeColor, PipePuzzle, etc.
├── Services/
│   └── PipesPuzzleProvider.swift # Singleton cycling through puzzles by day-of-year
├── ViewModels/
│   └── PipesGameViewModel.swift  # Game logic, drag handling, win condition
└── Views/
    ├── PipesGameView.swift       # Main game view with header, timer, overlay
    └── PipesGridView.swift       # Grid rendering, path drawing, drag gesture
```

### Current Drag Behavior (PipesGridView.swift:62-72)
- Uses `DragGesture(minimumDistance: 0)`
- Converts touch location to grid cell coordinates (row, col)
- Calls `viewModel.handleDragAt(row:col:)` which processes cell-by-cell
- Paths are drawn as thick strokes connecting cell centers

### Current Path Rendering (PipesGridView.swift:32-53)
- Iterates through `viewModel.paths[color]` array of `PipePosition`
- Creates SwiftUI `Path` connecting cell center points
- Applies `.stroke()` with `lineWidth: cellSize * 0.45`, rounded caps/joins

---

## Feature 1: Flowing Line Animation

### Goal
Replace the current discrete cell-snapping behavior with a smooth, animated line that follows the user's finger and then "snaps" into place when entering a valid cell.

### Implementation Plan

#### 1.1 Add Real-Time Drag Position Tracking

**File: `PipesGameViewModel.swift`**

Add new properties:
```swift
// Current finger position for live preview (in grid coordinates, not cell indices)
var liveDrawPosition: CGPoint? = nil

// Whether we're currently in an active drag
var isDrawing: Bool = false
```

**File: `PipesGridView.swift`**

Modify the drag gesture to track continuous position:
```swift
DragGesture(minimumDistance: 0)
    .onChanged { value in
        // Pass raw position for live preview
        viewModel.liveDrawPosition = value.location

        // Still calculate cell for snapping logic
        let col = clamp(Int(value.location.x / cellSize), 0, viewModel.gridSize - 1)
        let row = clamp(Int(value.location.y / cellSize), 0, viewModel.gridSize - 1)
        viewModel.handleDragAt(row: row, col: col)
    }
    .onEnded { _ in
        viewModel.liveDrawPosition = nil
        viewModel.handleDragEnd()
    }
```

#### 1.2 Create Animated Path Preview

**File: `PipesGridView.swift`**

Add a "live" path segment from the last confirmed cell to the current finger position:
```swift
// After drawing the confirmed path, draw live preview segment
if let color = viewModel.activeColor,
   let path = viewModel.paths[color],
   let lastPos = path.last,
   let livePos = viewModel.liveDrawPosition {

    let lastPoint = CGPoint(
        x: CGFloat(lastPos.col) * cellSize + cellSize / 2,
        y: CGFloat(lastPos.row) * cellSize + cellSize / 2
    )

    Path { p in
        p.move(to: lastPoint)
        p.addLine(to: livePos)
    }
    .stroke(
        color.displayColor.opacity(0.6),
        style: StrokeStyle(
            lineWidth: cellSize * 0.35,
            lineCap: .round
        )
    )
}
```

#### 1.3 Add Path Animation on Cell Entry

When a new cell is confirmed (added to path), animate the transition:

**File: `PipesGameViewModel.swift`**

Modify `continueDrag(to:)` to trigger animation:
```swift
private func continueDrag(to pos: PipePosition) {
    // ... existing validation ...

    paths[color]?.append(pos)

    // Trigger animation
    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
        rebuildGrid()
    }

    // ... rest of method ...
}
```

#### 1.4 Add "Snap" Animation Effect

Create a subtle pulse/glow when a cell is successfully claimed:

**File: Create new `PipesCellAnimationModifier.swift`** (in Views folder)
```swift
struct CellSnapModifier: ViewModifier {
    let isNewlyFilled: Bool
    @State private var scale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onChange(of: isNewlyFilled) { _, newValue in
                if newValue {
                    withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
                        scale = 1.15
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            scale = 1.0
                        }
                    }
                }
            }
    }
}
```

#### 1.5 Smooth Path Curves (Optional Enhancement)

Instead of straight lines between cell centers, use Catmull-Rom or bezier curves:

**File: `PipesGridView.swift`**

Replace linear path drawing with curved interpolation:
```swift
// Convert path points to smooth curve
if path.count >= 2 {
    Path { p in
        let points = path.map { pos -> CGPoint in
            CGPoint(
                x: CGFloat(pos.col) * cellSize + cellSize / 2,
                y: CGFloat(pos.row) * cellSize + cellSize / 2
            )
        }

        p.move(to: points[0])

        if points.count == 2 {
            p.addLine(to: points[1])
        } else {
            // Use quadratic curves for smoother appearance
            for i in 1..<points.count {
                let prev = points[i - 1]
                let curr = points[i]
                let midPoint = CGPoint(
                    x: (prev.x + curr.x) / 2,
                    y: (prev.y + curr.y) / 2
                )

                if i == 1 {
                    p.addLine(to: midPoint)
                } else {
                    p.addQuadCurve(to: midPoint, control: prev)
                }

                if i == points.count - 1 {
                    p.addLine(to: curr)
                }
            }
        }
    }
    .stroke(...)
}
```

### Testing Checklist for Feature 1
- [ ] Line follows finger smoothly during drag
- [ ] Line "snaps" to cell center when entering valid cell
- [ ] Preview line has slightly lower opacity than confirmed path
- [ ] Animation plays when path extends to new cell
- [ ] Backtracking animates smoothly (line retracts)
- [ ] No visual glitches at cell boundaries
- [ ] Performance is smooth on older devices (iPhone 11, etc.)

---

## Feature 2: Claude-Generated Daily Puzzles

### Goal
Replace the static 7-puzzle pool with AI-generated puzzles that are:
- Unique each day
- Guaranteed to be solvable
- Appropriately difficult (varied difficulty levels)
- Cached on the backend to ensure all users get the same puzzle

### Architecture Decision

**Option A: Client-side generation** - Generate on device, use date as seed
- Pros: Works offline, no backend dependency
- Cons: Complex solver logic on device, can't use Claude API directly

**Option B: Backend generation** (RECOMMENDED)
- Pros: Use Claude API for generation, validate solvability server-side, consistent across users
- Cons: Requires network, backend work

**Recommended: Option B with fallback to static puzzles**

### Implementation Plan

#### 2.1 Backend Puzzle Generation Service

**File: Create `tapin-backend/services/pipes_puzzle_generator.py`**

```python
import anthropic
import json
from datetime import date
import hashlib

class PipesPuzzleGenerator:
    """Generates and validates Pipes puzzles using Claude API."""

    def __init__(self, api_key: str):
        self.client = anthropic.Anthropic(api_key=api_key)

    def generate_puzzle(self, difficulty: str = "medium", grid_size: int = 5) -> dict:
        """Generate a puzzle using Claude."""

        prompt = f"""Generate a Pipes puzzle (Flow Free style) with these specifications:

        Grid Size: {grid_size}x{grid_size}
        Difficulty: {difficulty}

        Rules:
        1. Place pairs of colored endpoints on a grid
        2. Each color must have exactly 2 endpoints
        3. The puzzle must be solvable by connecting each pair with a path
        4. Paths cannot cross each other
        5. All cells must be filled when solved
        6. Use 5 colors for a 5x5 grid: red, blue, green, yellow, orange

        For {difficulty} difficulty:
        - easy: Short, direct paths with minimal turns
        - medium: Moderate path lengths with some interweaving
        - hard: Long paths that weave around each other

        Return ONLY a JSON object in this exact format:
        {{
            "size": {grid_size},
            "pairs": [
                {{"color": "red", "start": {{"row": 0, "col": 0}}, "end": {{"row": 2, "col": 3}}}},
                ...
            ],
            "solution": [
                {{"color": "red", "path": [{{"row": 0, "col": 0}}, {{"row": 0, "col": 1}}, ...]}},
                ...
            ]
        }}

        Important: Verify the puzzle is solvable before returning. The solution paths must:
        - Connect each pair's start to end
        - Not overlap with any other path
        - Fill all {grid_size * grid_size} cells exactly once
        """

        response = self.client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=2000,
            messages=[{"role": "user", "content": prompt}]
        )

        # Parse and validate response
        puzzle_json = self._extract_json(response.content[0].text)

        if self._validate_puzzle(puzzle_json):
            return puzzle_json
        else:
            raise ValueError("Generated puzzle failed validation")

    def _validate_puzzle(self, puzzle: dict) -> bool:
        """Verify the puzzle is valid and solvable."""
        size = puzzle["size"]
        solution = puzzle.get("solution", [])

        # Check all cells are covered exactly once
        covered = set()
        for path_data in solution:
            for cell in path_data["path"]:
                pos = (cell["row"], cell["col"])
                if pos in covered:
                    return False  # Overlap detected
                covered.add(pos)

        expected_cells = size * size
        if len(covered) != expected_cells:
            return False  # Not all cells filled

        # Verify paths connect endpoints
        for pair in puzzle["pairs"]:
            color = pair["color"]
            start = (pair["start"]["row"], pair["start"]["col"])
            end = (pair["end"]["row"], pair["end"]["col"])

            solution_path = next(
                (p for p in solution if p["color"] == color), None
            )
            if not solution_path:
                return False

            path = [(c["row"], c["col"]) for c in solution_path["path"]]
            if path[0] != start or path[-1] != end:
                if path[0] != end or path[-1] != start:
                    return False

        return True

    def _extract_json(self, text: str) -> dict:
        """Extract JSON from Claude's response."""
        # Find JSON block in response
        start = text.find("{")
        end = text.rfind("}") + 1
        if start == -1 or end == 0:
            raise ValueError("No JSON found in response")
        return json.loads(text[start:end])
```

#### 2.2 Backend API Endpoint

**File: Create `tapin-backend/api/pipes.py`**

```python
from flask import Blueprint, jsonify, request
from datetime import date
from services.pipes_puzzle_generator import PipesPuzzleGenerator
from services.firestore_client import get_firestore_client

pipes_bp = Blueprint("pipes", __name__, url_prefix="/api/pipes")

@pipes_bp.route("/daily", methods=["GET"])
def get_daily_puzzle():
    """Get today's Pipes puzzle (cached or generated)."""
    today = date.today().isoformat()
    db = get_firestore_client()

    # Check cache first
    cached = db.collection("pipes_puzzles").document(today).get()
    if cached.exists:
        return jsonify(cached.to_dict())

    # Generate new puzzle
    try:
        generator = PipesPuzzleGenerator(api_key=get_claude_api_key())
        puzzle = generator.generate_puzzle(difficulty=get_daily_difficulty())

        # Cache for the day
        puzzle["date"] = today
        puzzle["generated_at"] = datetime.utcnow().isoformat()
        db.collection("pipes_puzzles").document(today).set(puzzle)

        # Return without solution (don't spoil it!)
        response = {k: v for k, v in puzzle.items() if k != "solution"}
        return jsonify(response)

    except Exception as e:
        # Fallback to static puzzle
        return jsonify(get_fallback_puzzle(today)), 200

def get_daily_difficulty() -> str:
    """Rotate difficulty by day of week."""
    weekday = date.today().weekday()
    difficulties = ["easy", "easy", "medium", "medium", "medium", "hard", "hard"]
    return difficulties[weekday]
```

#### 2.3 iOS Service Layer

**File: Update `PipesPuzzleProvider.swift`**

```swift
import Foundation

class PipesPuzzleProvider {
    static let shared = PipesPuzzleProvider()

    private init() {}

    private let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt
    }()

    private var cachedPuzzle: (date: String, puzzle: PipePuzzle)?

    func dateKey(for date: Date = Date()) -> String {
        dateFormatter.string(from: date)
    }

    /// Fetch daily puzzle from backend with fallback to static puzzles
    func fetchDailyPuzzle() async -> PipePuzzle {
        let today = dateKey()

        // Return cached if available
        if let cached = cachedPuzzle, cached.date == today {
            return cached.puzzle
        }

        // Try fetching from backend
        do {
            let puzzle = try await fetchFromBackend()
            cachedPuzzle = (today, puzzle)
            return puzzle
        } catch {
            print("Failed to fetch puzzle from backend: \(error)")
            return fallbackPuzzle()
        }
    }

    private func fetchFromBackend() async throws -> PipePuzzle {
        guard let url = URL(string: "\(APIConfig.baseURL)/api/pipes/daily") else {
            throw URLError(.badURL)
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(PipePuzzleResponse.self, from: data)

        return PipePuzzle(
            size: response.size,
            pairs: response.pairs.map { pair in
                PipeEndpointPair(
                    color: PipeColor(rawValue: pair.color) ?? .red,
                    start: PipePosition(row: pair.start.row, col: pair.start.col),
                    end: PipePosition(row: pair.end.row, col: pair.end.col)
                )
            }
        )
    }

    /// Fallback to static puzzles if backend unavailable
    func fallbackPuzzle() -> PipePuzzle {
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let index = (dayOfYear - 1) % PipePuzzle.puzzles.count
        return PipePuzzle.puzzles[index]
    }

    // Legacy sync method for backward compatibility
    func puzzleForDate(_ date: Date = Date()) -> PipePuzzle {
        if let cached = cachedPuzzle, cached.date == dateKey(for: date) {
            return cached.puzzle
        }
        return fallbackPuzzle()
    }
}

// MARK: - Response Models

struct PipePuzzleResponse: Codable {
    let size: Int
    let pairs: [PairResponse]
    let date: String
}

struct PairResponse: Codable {
    let color: String
    let start: PositionResponse
    let end: PositionResponse
}

struct PositionResponse: Codable {
    let row: Int
    let col: Int
}
```

#### 2.4 Update ViewModel for Async Loading

**File: Update `PipesGameViewModel.swift`**

```swift
@Observable
class PipesGameViewModel {
    // ... existing properties ...

    var isLoadingPuzzle: Bool = false
    var loadError: String? = nil

    init() {
        currentPuzzle = PipesPuzzleProvider.shared.fallbackPuzzle()
        Task {
            await loadDailyPuzzleAsync()
        }
    }

    @MainActor
    func loadDailyPuzzleAsync() async {
        isLoadingPuzzle = true
        loadError = nil

        let puzzle = await PipesPuzzleProvider.shared.fetchDailyPuzzle()

        currentPuzzle = puzzle
        gridSize = puzzle.size
        gameState = .playing
        moves = 0
        // ... reset other state ...

        endpointMap = [:]
        for pair in currentPuzzle.pairs {
            endpointMap[pair.start] = pair.color
            endpointMap[pair.end] = pair.color
        }

        rebuildGrid()
        isLoadingPuzzle = false
    }

    // Keep sync method for reset
    func resetPuzzle() {
        // ... existing reset logic ...
    }
}
```

#### 2.5 Add Loading State to View

**File: Update `PipesGameView.swift`**

Add loading indicator when puzzle is being fetched:
```swift
var body: some View {
    ZStack {
        // ... existing content ...

        if viewModel.isLoadingPuzzle {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(Color.ucdGold)

                Text("Loading today's puzzle...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "#0f172a").opacity(0.9))
            )
        }
    }
}
```

### Testing Checklist for Feature 2

#### Backend Testing
- [ ] Generate 10 puzzles and verify all are solvable
- [ ] Test validation rejects invalid puzzles (overlapping paths, unfilled cells)
- [ ] Test caching: same puzzle returned for same day
- [ ] Test difficulty rotation by day of week
- [ ] Test fallback when Claude API fails
- [ ] Load test: handle multiple concurrent requests

#### iOS Testing
- [ ] App loads puzzle from backend successfully
- [ ] Loading indicator displays while fetching
- [ ] Fallback to static puzzle when offline
- [ ] Fallback to static puzzle when backend error
- [ ] Puzzle persists across app restarts (same day)
- [ ] New puzzle loads on new day

#### Solvability Testing
Run automated validation:
```python
# Test script: test_puzzle_generation.py
def test_generated_puzzles():
    generator = PipesPuzzleGenerator(api_key=TEST_KEY)

    for difficulty in ["easy", "medium", "hard"]:
        for _ in range(5):
            puzzle = generator.generate_puzzle(difficulty=difficulty)
            assert validate_puzzle_solvable(puzzle), f"Failed: {difficulty}"
            print(f"✓ {difficulty} puzzle valid")
```

---

## Implementation Order

### Phase 1: Flowing Animation (Client-side only)
1. Add `liveDrawPosition` tracking to ViewModel
2. Update drag gesture to pass continuous position
3. Add preview line rendering
4. Add snap animation on cell entry
5. Test and polish

### Phase 2: Backend Puzzle Generation
1. Create Python puzzle generator service
2. Add validation logic
3. Create `/api/pipes/daily` endpoint
4. Add Firestore caching
5. Deploy to Cloud Run

### Phase 3: iOS Integration
1. Update `PipesPuzzleProvider` for async fetching
2. Add response models
3. Update ViewModel with loading state
4. Add loading UI
5. Test offline fallback

### Phase 4: Polish & QA
1. Extensive solvability testing
2. Performance profiling
3. Edge case handling
4. User testing feedback

---

## API Contract

### GET /api/pipes/daily

**Response (200 OK):**
```json
{
    "size": 5,
    "pairs": [
        {
            "color": "red",
            "start": {"row": 0, "col": 0},
            "end": {"row": 2, "col": 3}
        },
        {
            "color": "blue",
            "start": {"row": 0, "col": 4},
            "end": {"row": 4, "col": 1}
        }
    ],
    "date": "2026-03-02",
    "difficulty": "medium",
    "generated_at": "2026-03-02T00:00:00Z"
}
```

**Note:** Solution is intentionally omitted from response to prevent cheating.

---

## Files to Create/Modify

### New Files
- `tapin-backend/services/pipes_puzzle_generator.py`
- `tapin-backend/api/pipes.py`
- `TapInApp/Games/Pipes/Views/PipesCellAnimationModifier.swift` (optional)

### Modified Files
- `TapInApp/Games/Pipes/ViewModels/PipesGameViewModel.swift`
- `TapInApp/Games/Pipes/Views/PipesGridView.swift`
- `TapInApp/Games/Pipes/Views/PipesGameView.swift`
- `TapInApp/Games/Pipes/Services/PipesPuzzleProvider.swift`
- `tapin-backend/app.py` (register blueprint)

---

## Notes for Implementation

1. **Animation Performance**: Use `drawingGroup()` modifier if path rendering causes lag on older devices

2. **Claude Prompt Engineering**: The puzzle generation prompt may need iteration. Start with the prompt above and refine based on output quality

3. **Fallback Strategy**: Always maintain the static puzzle pool as fallback. Never leave users unable to play

4. **Testing Solvability**: Consider implementing a simple backtracking solver on the backend to verify generated puzzles before serving

5. **Rate Limiting**: Cache aggressively - generate at most 1 puzzle per day per difficulty level

6. **Offline Mode**: If the device is offline at startup, show static puzzle immediately without waiting for network timeout
