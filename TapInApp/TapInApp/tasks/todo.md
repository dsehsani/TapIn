# To-Do: Remove All Onboarding Tips

## Plan
- [x] Delete 3 onboarding files from disk
- [x] Remove `.pulsingHotspot(...)` from `GamesView.swift`
- [x] Remove `.pulsingHotspot(...)` from `NewsView.swift`
- [x] Remove overlay blocks + dismiss handler from `ContentView.swift`
- [x] Remove `resetTips` flag + `OnboardingManager` call from `TapInAppApp.swift`
- [x] Remove `markTutorialsAsSeen()` + call site from `GamesViewModel.swift`
- [x] Add one-time UserDefaults cleanup in `TapInAppApp.swift`
- [x] Remove files from Xcode project (already gone from pbxproj)
- [x] Verify: grep for all removed type names returns zero results
- [x] Clean up empty `Components/Onboarding/` directory

## Results
- Deleted: `OnboardingManager.swift`, `OnboardingTipView.swift`, `PulsingHotspotModifier.swift`
- Modified: `GamesView.swift`, `NewsView.swift`, `ContentView.swift`, `TapInAppApp.swift`, `GamesViewModel.swift`
- Zero remaining references to removed types
- One-time UserDefaults cleanup added for orphaned keys
