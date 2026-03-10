# TapIn Profile Fixes — Implementation Prompt

## Problems to Fix

Three distinct but related issues:

1. **Edit Profile UX** — The save action requires scrolling to the bottom to tap "Save Changes". It should be a checkmark button in the top-right of the header bar, matching standard iOS sheet conventions.
2. **Profile icon mismatch on News Screen** — `TopNavigationBar` is a plain `struct` that reads `UserDefaults` at render time. It has no reactive observer, so it never updates when the profile image changes. The initials fallback also reads from the wrong `UserDefaults` key (`"userName"` which is never written — the name is stored inside the encoded `User` object under `"currentUser"`), meaning it always shows "U".
3. **Profile image not persisted across devices or after sign-out** — `ProfileViewModel.updateProfile()` saves the image only to `UserDefaults` (device-local). It never calls `UserAPIService.uploadProfileImage()`. On a new device or after signing back in, the image is gone because it was never uploaded to the backend.

---

## Fix 1: Checkmark Save Button in Header

### File: `TapInApp/Views/EditProfileView.swift`

Replace the current `headerBar` computed property (which has only an `xmark` dismiss button on the left and a `Spacer`) with a two-button header: dismiss (`xmark`) on the left, save (`checkmark`) on the right.

**Current `headerBar` (lines 123–138):**
```swift
private var headerBar: some View {
    HStack {
        Button(action: { dismiss() }) {
            Image(systemName: "xmark")
                ...
        }
        Spacer()
    }
    ...
}
```

**Replace with:**
```swift
private var headerBar: some View {
    HStack {
        // Dismiss — discards changes
        Button(action: { dismiss() }) {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 42, height: 42)
                .background(.white.opacity(0.15), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
        }

        Spacer()

        // Save — commits changes and dismisses
        Button(action: {
            Task {
                isSaving = true
                await viewModel.updateProfile(
                    name: name,
                    email: email,
                    year: year,
                    imageData: profileImageData,
                    interests: Array(selectedInterests)
                )
                isSaving = false
                dismiss()
            }
        }) {
            Group {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.85)
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 42, height: 42)
            .background(.white.opacity(0.15), in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
        }
        .disabled(isSaving)
    }
    .padding(.horizontal, 24)
    .padding(.top, 16)
    .padding(.bottom, 20)
}
```

Also **remove the `saveButton` computed property entirely** (lines 333–364) and remove its call from the `ScrollView` `VStack` (lines 70–73). The save action now only lives in the header checkmark.

The `isSaving` `@State` variable stays — it's used in both the checkmark button (spinner) and to `disable` the button while saving.

---

## Fix 2: Reactive Profile Icon in TopNavigationBar

### Root Causes

**Root Cause A — No reactivity:**
`TopNavigationBar` is a plain SwiftUI `struct`. It reads `UserDefaults.standard.data(forKey: "profileImageData")` directly in `var body`, which only runs when the parent view redraws. If the profile image changes while `NewsView` is alive, `TopNavigationBar` never redraws because nothing it observes has changed.

**Root Cause B — Wrong UserDefaults key for initials:**
The initials fallback reads:
```swift
UserDefaults.standard.string(forKey: "userName")
```
But `AppState.persistState()` never writes a `"userName"` key. The user's name is encoded into a `User` struct and stored under `"currentUser"`. The `"userName"` key is always `nil`, so the fallback always resolves to `"U"`.

### Fix: Observe `AppState` in `TopNavigationBar`

**File:** `TapInApp/Components/TopNavigationBar.swift`

Make `TopNavigationBar` observe `AppState.shared` so it redraws whenever `currentUser` or the profile image changes.

```swift
struct TopNavigationBar: View {
    var onSettingsTap: () -> Void
    var onBellTap: () -> Void = {}
    var hasUnseenNotifications: Bool = false

    @Environment(\.colorScheme) var colorScheme

    // Observe AppState so the avatar updates immediately after profile edits
    @ObservedObject private var appState = AppState.shared

    var body: some View {
        HStack(alignment: .center) {
            Text(Self.currentDateString)
                .font(.system(size: 34, weight: .black))
                .foregroundColor(Color.adaptiveText(colorScheme))

            Spacer()

            // Notification bell (unchanged)
            Button(action: onBellTap) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color.adaptiveText(colorScheme))
                        .frame(width: 42, height: 42)

                    if hasUnseenNotifications {
                        Circle()
                            .fill(.red)
                            .frame(width: 10, height: 10)
                            .offset(x: -6, y: 6)
                    }
                }
            }
            .buttonStyle(.plain)

            // Profile avatar button
            Button(action: onSettingsTap) {
                profileAvatar
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: - Profile Avatar

    private var profileAvatar: some View {
        Group {
            if let data = UserDefaults.standard.data(forKey: "profileImageData"),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 42, height: 42)
                    .clipShape(Circle())
            } else {
                // Fix: read name from AppState, not the missing "userName" UserDefaults key
                let initial = String(appState.userName.prefix(1)).uppercased()

                Text(initial)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [Color(hex: "#1e2545"), Color(hex: "#302050")]
                                : [Color.accentCoral, Color.accentOrange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
            }
        }
    }

    // ... date/ordinal helpers unchanged ...
}
```

The key changes:
- Add `@ObservedObject private var appState = AppState.shared` — when `AppState.currentUser` changes (which `ProfileViewModel.updateProfile()` already does), the nav bar redraws.
- Change the initials fallback from `UserDefaults.standard.string(forKey: "userName") ?? "U"` to `appState.userName` — this reads from `AppState` which always reflects the current user correctly.

### Additional: Trigger nav bar redraw after image save

`AppState.currentUser` changing is enough to trigger a redraw of `TopNavigationBar` via `@ObservedObject`. However, `profileImageData` is saved to `UserDefaults` separately and doesn't touch `AppState.currentUser`. To guarantee the nav bar re-renders after an image change, add a `profileImageVersion` counter to `AppState` that gets incremented each time the profile image is saved:

**File:** `TapInApp/App/AppState.swift`

```swift
// Add to AppState published properties:
@Published var profileImageVersion: Int = 0
```

**File:** `TapInApp/ViewModels/ProfileViewModel.swift` — in `updateProfile()`, after saving the image:

```swift
if let imageData {
    UserDefaults.standard.set(imageData, forKey: "profileImageData")
    AppState.shared.profileImageVersion += 1  // triggers nav bar redraw
}
```

Then in `TopNavigationBar.profileAvatar`, reference `appState.profileImageVersion` anywhere in the view body (a hidden `Text` with 0 opacity, or just in the `Group`'s evaluation) to force SwiftUI to treat it as a dependency:

```swift
// Force SwiftUI to track profileImageVersion as a dependency
let _ = appState.profileImageVersion

if let data = UserDefaults.standard.data(forKey: "profileImageData"), ...
```

---

## Fix 3: Profile Image Persistence Across Devices

### Root Cause

`ProfileViewModel.updateProfile()` saves the image to `UserDefaults` only:
```swift
// ProfileViewModel.swift line 104–106
if let imageData {
    UserDefaults.standard.set(imageData, forKey: "profileImageData")
}
```

`UserAPIService.updateProfile()` (called right after) only sends `email`, `username`, and `interests` — not the image. The `uploadProfileImage()` method exists in `UserAPIService` but is never called from the edit profile flow. As a result, the profile photo only lives on the current device.

### Fix: Upload image to backend on profile save

**File:** `TapInApp/ViewModels/ProfileViewModel.swift` — extend `updateProfile()`:

```swift
func updateProfile(name: String, email: String, year: String, imageData: Data?, interests: [String] = []) async {
    guard var currentUser = AppState.shared.currentUser else { return }

    currentUser.name = name
    currentUser.email = email
    currentUser.year = year.isEmpty ? nil : year
    currentUser.interests = interests.isEmpty ? nil : interests
    AppState.shared.currentUser = currentUser

    // Persist image locally
    if let imageData {
        UserDefaults.standard.set(imageData, forKey: "profileImageData")
        AppState.shared.profileImageVersion += 1

        // Also scope it to the provider key so it survives sign-out/re-login
        let providerKey = UserDefaults.standard.string(forKey: "appleUserId")
            ?? AppState.shared.smsUserId
            ?? ""
        if !providerKey.isEmpty {
            UserDefaults.standard.set(imageData, forKey: "profileImage_\(providerKey)")
        }

        // Upload to backend (best-effort — don't block save on failure)
        if let token = AppState.shared.backendToken {
            Task {
                do {
                    let imageURL = try await UserAPIService.shared.uploadProfileImage(
                        token: token,
                        imageData: imageData
                    )
                    // Store the remote URL on the user object so other devices can fetch it
                    var updatedUser = AppState.shared.currentUser
                    updatedUser?.profileImageURL = imageURL
                    AppState.shared.currentUser = updatedUser
                    AppState.shared.persistStatePublic()
                } catch {
                    // Upload failed — image stays local only, silently continue
                    #if DEBUG
                    print("ProfileViewModel: image upload failed — \(error.localizedDescription)")
                    #endif
                }
            }
        }
    }

    // Update local profile cache (survives sign-out)
    updateLocalProfileCache(name: name, email: email, year: year, interests: interests)

    // Persist AppState to UserDefaults
    AppState.shared.persistStatePublic()

    // Sync name/email/interests to backend
    if let token = AppState.shared.backendToken {
        try? await UserAPIService.shared.updateProfile(
            token: token,
            email: email.isEmpty ? nil : email,
            username: name.isEmpty ? nil : name,
            interests: interests.isEmpty ? nil : interests
        )
    }
}
```

### Fix: Download and display profile image on login from another device

When a returning user logs in (in `OnboardingViewModel` — all three auth paths), after `AppState.shared.currentUser` is set, check if `currentUser.profileImageURL` is populated and the local device doesn't have the image yet. If so, download it:

Add a helper to `ProfileViewModel` or create a shared utility:

```swift
/// Downloads the profile image from the backend URL and stores it locally.
/// Call this after session restore or returning-user login.
static func syncProfileImageIfNeeded() async {
    guard UserDefaults.standard.data(forKey: "profileImageData") == nil,
          let imageURL = AppState.shared.currentUser?.profileImageURL,
          let url = URL(string: imageURL) else { return }

    do {
        let (data, _) = try await URLSession.shared.data(from: url)
        UserDefaults.standard.set(data, forKey: "profileImageData")
        AppState.shared.profileImageVersion += 1
    } catch {
        #if DEBUG
        print("ProfileViewModel: image sync failed — \(error.localizedDescription)")
        #endif
    }
}
```

Call `ProfileViewModel.syncProfileImageIfNeeded()` in two places:

1. **`AppState.restoreSession()`** — after successfully fetching and setting the user profile from the backend.
2. **`OnboardingViewModel`** — in all three returning-user paths (Apple, Google, Phone), after setting `AppState.shared.isAuthenticated = true`.

### Fix: Restore provider-scoped profile image on re-login (offline fallback)

This is a follow-up to the bug fix from `bug_fixes_prompt.md`. In the local-profile-cache restore path (when the backend is unreachable), also restore the provider-scoped image:

```swift
// In OnboardingViewModel.restoreUserData(providerKey:user:)
if let imageData = UserDefaults.standard.data(forKey: "profileImage_\(providerKey)") {
    UserDefaults.standard.set(imageData, forKey: "profileImageData")
    AppState.shared.profileImageVersion += 1
}
```

This was already outlined in `bug_fixes_prompt.md` — make sure this is wired up if it hasn't been done yet.

---

## Files to Modify

| File | Change |
|------|--------|
| `TapInApp/Views/EditProfileView.swift` | Add checkmark button to `headerBar`, remove `saveButton` property and its call site |
| `TapInApp/Components/TopNavigationBar.swift` | Add `@ObservedObject private var appState = AppState.shared`, fix initials to read from `appState.userName`, add `let _ = appState.profileImageVersion` dependency |
| `TapInApp/App/AppState.swift` | Add `@Published var profileImageVersion: Int = 0` |
| `TapInApp/ViewModels/ProfileViewModel.swift` | In `updateProfile()`: increment `profileImageVersion`, upload image via `UserAPIService.uploadProfileImage()`, save provider-scoped image key. Add `syncProfileImageIfNeeded()` static helper |
| `TapInApp/App/AppState.swift` — `restoreSession()` | Call `ProfileViewModel.syncProfileImageIfNeeded()` after user is restored |
| `TapInApp/Onboarding/OnboardingViewModel.swift` | Call `ProfileViewModel.syncProfileImageIfNeeded()` in all three returning-user auth paths |

---

## Testing

- [ ] Open Edit Profile → checkmark button visible top-right immediately, no scrolling required
- [ ] Tap checkmark → spinner appears, sheet dismisses after save
- [ ] Tap X → sheet dismisses without saving any changes
- [ ] Save a new profile photo → nav bar avatar in News screen updates instantly without navigating away
- [ ] Save a new name → nav bar initials update instantly if no photo is set
- [ ] Set profile photo on Device A → sign out → sign back in on Device B → photo appears
- [ ] Set profile photo on Device A → sign out on same device → sign back in → photo appears (provider-scoped local cache)
- [ ] New user with no photo → nav bar shows correct first initial (not "U")
