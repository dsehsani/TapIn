The bottom tab bar is floating too high above the bottom of the screen instead of sitting flush with the iOS safe area.

Fix the bottom navigation so it:
    •    Properly respects the iOS safe area (including devices with a home indicator)
    •    Is anchored to the bottom of the screen
    •    Does not add extra bottom padding or margins
    •    Uses the native tab bar height behavior on iOS

Check for:
    •    Extra .padding(.bottom)
    •    Wrapping the TabView in a VStack or ZStack incorrectly
    •    Ignoring .ignoresSafeArea(.keyboard) or .safeAreaInset misuse

The goal is for the tab bar to sit flush at the bottom like a standard iOS app, with icons aligned correctly and no visible gap below or above it.
