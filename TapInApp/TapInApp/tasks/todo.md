# To-Do: Pipes Completion Sheet — Pull-Up Leaderboard

## Plan
- [x] Add `isLeaderboardExpanded` state variable
- [x] Change leaderboard fetch limit from 5 to 10
- [x] Replace DragGesture to handle both up (expand) and down (collapse/dismiss)
- [x] Add `frame(maxHeight:)` to sheet VStack for collapsed/expanded sizing
- [x] Update `pipesLeaderboardSection` with collapsed vs expanded views + "See top 10" hint
- [x] Add `pipesFullLeaderboardList` for expanded top-10 list with `rankColor` helper
- [x] Reset `isLeaderboardExpanded` on dismiss (backdrop tap, drag dismiss, onChange)
- [x] Add animation value for `isLeaderboardExpanded` on the overlay

## Results
- Sheet is two-state: collapsed (~60% height, podium top 3) and expanded (~92% height, full top-10 list)
- Drag up ≥60pt expands, drag down ≥80pt from expanded collapses, drag down ≥120pt from collapsed dismisses
- "See top 10" hint shown in collapsed header, disappears when expanded
- Full leaderboard list shows rank, username, moves, time; current user highlighted in gold
- `isLeaderboardExpanded` resets on every dismiss path (backdrop, drag, onChange)
