# TapIn — Pipes Completion Sheet: Live Pull-Up Leaderboard

## Problem

After completing all 5 Pipes puzzles, the bottom sheet shows a static podium (top 3 only). There is a drag indicator pill at the top of the sheet that implies it can be pulled up, but the `DragGesture` only handles downward drags (to dismiss). Dragging up does nothing. Dragging down correctly dismisses back to the completed game state.

**Goal:** Make the sheet two-state:
- **Collapsed (default):** current podium + stats view, sits at ~60% screen height
- **Expanded (pull up):** full scrollable top-10 leaderboard, covers ~92% of the screen

Dragging **up** expands. Dragging **down** from expanded collapses back. Dragging **down** from collapsed dismisses the sheet entirely (existing behavior — keep it).

---

## Files to Modify

- `TapInApp/Views/PipesGameView.swift` — all changes are here

---

## Changes

### 1. Add Expanded State

Add a new state variable to track whether the sheet is in collapsed or expanded mode:

```swift
@State private var sheetDragOffset: CGFloat = 0        // already exists
@State private var isLeaderboardExpanded: Bool = false  // ← add this
```

---

### 2. Fetch Top 10 Instead of Top 5

In `fetchPipesLeaderboard()`, change the limit from `5` to `10`:

```swift
// Change:
let entries = try await LeaderboardService.shared.fetchPipesLeaderboard(for: viewModel.currentDateKey, limit: 5)

// To:
let entries = try await LeaderboardService.shared.fetchPipesLeaderboard(for: viewModel.currentDateKey, limit: 10)
```

---

### 3. Replace the `DragGesture` in `allCompleteOverlay`

The current gesture only responds to downward drags. Replace it with one that handles both directions:

```swift
// Replace the existing .gesture(...) on the sheet VStack with:
.gesture(
    DragGesture()
        .onChanged { value in
            let dy = value.translation.height
            if isLeaderboardExpanded {
                // In expanded state: only allow dragging down (to collapse)
                if dy > 0 { sheetDragOffset = dy }
            } else {
                // In collapsed state: allow dragging both up (to expand) and down (to dismiss)
                sheetDragOffset = dy
            }
        }
        .onEnded { value in
            let dy = value.translation.height

            if isLeaderboardExpanded {
                // Expanded → drag down enough to collapse
                if dy > 80 {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        isLeaderboardExpanded = false
                    }
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    sheetDragOffset = 0
                }
            } else {
                if dy < -60 {
                    // Dragged up far enough → expand to show full leaderboard
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        isLeaderboardExpanded = true
                        sheetDragOffset = 0
                    }
                } else if dy > 120 {
                    // Dragged down far enough → dismiss the overlay (existing behavior)
                    withAnimation { viewModel.justCompletedAll = false }
                } else {
                    // Didn't drag far enough either way → snap back
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        sheetDragOffset = 0
                    }
                }
            }
        }
)
```

---

### 4. Make Sheet Height Respond to Expanded State

The sheet `VStack` currently has no explicit height constraint — it sizes to its content. In expanded mode, constrain it to fill most of the screen. Apply this to the outer `VStack` inside `allCompleteOverlay`:

```swift
VStack(spacing: 0) {
    // ... drag indicator, header, leaderboard, actions ...
}
.frame(maxHeight: isLeaderboardExpanded
    ? UIScreen.main.bounds.height * 0.92
    : UIScreen.main.bounds.height * 0.62)
.offset(y: sheetDragOffset)
```

---

### 5. Update `pipesLeaderboardSection` — Collapsed vs Expanded Views

Replace `pipesLeaderboardSection` so it renders differently depending on `isLeaderboardExpanded`:

```swift
@ViewBuilder
private func pipesLeaderboardSection(muted: Color, textPrimary: Color) -> some View {
    VStack(spacing: 12) {

        // Header row — same in both states
        HStack {
            HStack(spacing: 5) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Color.ucdGold)
                Text("LEADERBOARD")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundColor(muted)
            }
            Spacer()
            // Hint label — only shown when collapsed
            if !isLeaderboardExpanded {
                HStack(spacing: 3) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .semibold))
                    Text("See top 10")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(muted)
            }
        }
        .padding(.horizontal, 24)

        if isLoadingPipesLeaderboard {
            ProgressView()
                .padding(.vertical, 16)

        } else if pipesLeaderboardEntries.isEmpty {
            Text("No entries yet — you might be first!")
                .font(.system(size: 13))
                .foregroundColor(muted)
                .padding(.vertical, 8)

        } else if isLeaderboardExpanded {
            // ── EXPANDED: Full scrollable top-10 list ───────────────────────
            pipesFullLeaderboardList(muted: muted, textPrimary: textPrimary)
                .padding(.horizontal, 24)

        } else {
            // ── COLLAPSED: Podium (top 3 only) ──────────────────────────────
            pipesPodiumView(muted: muted, textPrimary: textPrimary)
                .padding(.horizontal, 24)

            // Show current user's rank if outside top 3
            if let me = pipesLeaderboardEntries.first(where: {
                viewModel.assignedUsername != nil && $0.username == viewModel.assignedUsername
            }), me.rank > 3 {
                HStack(spacing: 8) {
                    Text("#\(me.rank)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color.ucdGold)
                    Text(me.username)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(textPrimary)
                    Spacer()
                    Text("\(me.totalMoves)mv")
                        .font(.system(size: 12))
                        .foregroundColor(muted)
                    Text(formatTime(me.totalTimeSeconds))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(muted)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.ucdGold.opacity(0.1)))
                .padding(.horizontal, 24)
            }
        }
    }
}
```

---

### 6. Add `pipesFullLeaderboardList` — The Expanded View

Add this new private helper alongside the other leaderboard helpers:

```swift
@ViewBuilder
private func pipesFullLeaderboardList(muted: Color, textPrimary: Color) -> some View {
    ScrollView(showsIndicators: false) {
        VStack(spacing: 0) {
            ForEach(Array(pipesLeaderboardEntries.enumerated()), id: \.element.id) { index, entry in
                let isMe = viewModel.assignedUsername != nil && entry.username == viewModel.assignedUsername

                HStack(spacing: 12) {
                    // Rank
                    Text("#\(entry.rank)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(rankColor(for: entry.rank))
                        .frame(width: 32, alignment: .leading)

                    // Username
                    Text(entry.username)
                        .font(.system(size: 14, weight: isMe ? .bold : .semibold))
                        .foregroundColor(isMe ? Color.ucdGold : textPrimary)
                        .lineLimit(1)

                    Spacer()

                    // Moves
                    Text("\(entry.totalMoves) mv")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(muted)

                    // Time
                    Text(formatTime(entry.totalTimeSeconds))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(muted)
                        .frame(width: 44, alignment: .trailing)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isMe
                            ? Color.ucdGold.opacity(0.08)
                            : Color.clear)
                )
                .overlay(
                    // Subtle divider between rows (skip last)
                    index < pipesLeaderboardEntries.count - 1
                        ? AnyView(
                            Divider()
                                .opacity(0.4)
                                .padding(.leading, 44),
                            defaultValue: .bottom
                        )
                        : AnyView(EmptyView())
                )
            }
        }
    }
    .frame(maxHeight: 340)   // Fits ~8–10 rows; scrolls if needed
}

private func rankColor(for rank: Int) -> Color {
    switch rank {
    case 1: return Color.ucdGold
    case 2: return Color(hex: "#94a3b8")
    case 3: return Color(hex: "#b45309")
    default: return Color.secondary
    }
}
```

> Note: The `AnyView` overlay trick for the divider may need to be simplified to a plain `Divider` inside a `VStack` with `Spacer` — adjust if SwiftUI's overlay API gives trouble. The key is a subtle line between rows.

---

### 7. Reset `isLeaderboardExpanded` on Dismiss

When the overlay is dismissed (sheet dragged down, or backdrop tapped), reset expanded state so it defaults to collapsed next time:

```swift
// In the backdrop .onTapGesture:
.onTapGesture {
    withAnimation { viewModel.justCompletedAll = false }
    isLeaderboardExpanded = false   // ← add this
}

// In the drag gesture's dismiss branch:
} else if dy > 120 {
    withAnimation { viewModel.justCompletedAll = false }
    isLeaderboardExpanded = false   // ← add this
}
```

Also reset it in `.onChange(of: viewModel.justCompletedAll)`:

```swift
.onChange(of: viewModel.justCompletedAll) { _, isComplete in
    if isComplete && !viewModel.isArchiveMode {
        fetchPipesLeaderboard()
        NotificationService.shared.cancelTodaysPipesGiveawayReminder()
    }
    if !isComplete {
        isLeaderboardExpanded = false   // ← add this
        sheetDragOffset = 0             // ← and this
    }
}
```

---

## Acceptance Criteria

- [ ] After solving all 5 puzzles, the bottom sheet appears in its collapsed state (podium + stats), identical to today's behavior.
- [ ] A "↑ See top 10" hint label is visible in the collapsed leaderboard header.
- [ ] Dragging **up** on the sheet (≥ 60pt) expands it to show the full top-10 list with a spring animation.
- [ ] The expanded list shows rank, username, moves, and time for all 10 entries.
- [ ] The current user's row is highlighted in gold in both collapsed and expanded states.
- [ ] Dragging **down** on the expanded sheet (≥ 80pt) collapses it back to the podium view.
- [ ] Dragging **down** on the collapsed sheet (≥ 120pt) dismisses the overlay entirely (existing behavior — unchanged).
- [ ] The leaderboard fetches **10 entries** (`limit: 10`) instead of 5.
- [ ] `isLeaderboardExpanded` resets to `false` every time the overlay is dismissed, so re-opening always starts collapsed.
- [ ] Guest users are unaffected — the guest banner is shown instead of the leaderboard in both states.
- [ ] Archive mode is unaffected — no leaderboard section is shown for archive completions.

---

## Notes for the Implementer

- The drag threshold for "expand" (`-60pt` upward) is deliberately lower than "dismiss" (`120pt` downward) — expanding should feel easy, dismissing should feel intentional.
- The `frame(maxHeight:)` on the sheet `VStack` drives the size change. The spring animation on `isLeaderboardExpanded` makes it feel elastic rather than snapping.
- The `sheetDragOffset` should always reset to `0` at the end of a gesture, regardless of which branch was taken. This prevents the sheet getting stuck mid-drag if the user doesn't cross a threshold.
- The "↑ See top 10" hint disappears in expanded state so the header stays clean.
- The `AnyView` divider overlay is a SwiftUI workaround for conditional overlays — if it causes build issues, use a `ZStack` with a bottom-aligned `Divider` inside each row `VStack` instead.
