//
//  OnboardingViewModel.swift
//  TapInApp
//
//  Shared state and auth logic for the entire onboarding flow.
//

import SwiftUI
import Combine
import AuthenticationServices
import GoogleSignIn

enum OnboardingStep: Equatable {
    case welcome
    case signInOptions
    case phoneEntry
    case otpVerification
    case profileSetup
}

@MainActor
class OnboardingViewModel: ObservableObject {

    // MARK: - Navigation
    @Published var currentStep: OnboardingStep = .welcome

    // MARK: - Phone Auth State
    @Published var phoneNumber: String = ""
    @Published var otpCode: String = ""

    // MARK: - Profile State
    @Published var displayName: String = ""
    @Published var email: String = ""
    @Published var year: String = "Freshman"
    @Published var profileImageData: Data? = nil

    // MARK: - UI State
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // Keep delegate alive during Apple Sign-In flow
    private var appleSignInDelegate: AppleSignInDelegate?

    // Store Apple identity token for backend auth after profile setup
    private var appleIdentityToken: String?
    private var appleUserId: String?

    // Store Google identity token for backend auth after profile setup
    private var googleIdToken: String?
    private var googleUserId: String?

    /// E.164 formatted phone number (e.g. "+14155551234")
    var e164Phone: String {
        "+1" + phoneNumber.filter(\.isNumber)
    }

    // MARK: - Navigation

    func navigateTo(_ step: OnboardingStep) {
        withAnimation(.easeInOut(duration: 0.35)) {
            currentStep = step
        }
    }

    func goBack() {
        errorMessage = nil
        switch currentStep {
        case .signInOptions: navigateTo(.welcome)
        case .phoneEntry:    navigateTo(.signInOptions)
        case .otpVerification:
            otpCode = ""
            navigateTo(.phoneEntry)
        case .profileSetup:  navigateTo(.signInOptions)
        default: break
        }
    }

    // MARK: - Completion

    func completeOnboarding() async {
        isLoading = true
        let name = displayName.isEmpty ? "Aggie Student" : displayName

        // Register with backend FIRST — ensures user record exists in Firestore
        // so the same phone number is recognized on other devices.
        // Skip if we already got a token during returning-user check.
        if AppState.shared.backendToken == nil {
            await registerWithBackend(displayName: name)
        }

        // Push email to backend so it's stored in Firestore for uniqueness checks.
        // (Phone auth doesn't include the email — it's collected during profile setup.)
        if let token = AppState.shared.backendToken, !email.isEmpty {
            try? await UserAPIService.shared.updateProfile(token: token, email: email)
        }

        // Now mark as authenticated (even if backend failed — user can still use app locally)
        AppState.shared.currentUser = User(name: name, email: email, year: year)
        AppState.shared.isAuthenticated = true

        // Persist profile image separately (too large for Codable User)
        if let imageData = profileImageData {
            UserDefaults.standard.set(imageData, forKey: "profileImageData")
        }

        // Save a local profile record keyed by provider ID so we can recognize
        // returning users even if the backend is unreachable after sign-out.
        saveLocalProfile(name: name, email: email, year: year)

        AppState.shared.persistStatePublic()
        isLoading = false
    }

    // MARK: - Local Profile Cache (survives sign-out)

    /// Saves the user's profile locally so we can restore it on re-sign-in
    /// without depending on the backend.
    private func saveLocalProfile(name: String, email: String, year: String) {
        let providerKey = appleUserId ?? googleUserId ?? AppState.shared.smsUserId ?? ""
        guard !providerKey.isEmpty else { return }

        let profile: [String: String] = [
            "name": name,
            "email": email,
            "year": year,
            "providerKey": providerKey
        ]
        // Store under a key that won't be cleared on sign-out
        var profiles = UserDefaults.standard.dictionary(forKey: "localProfiles") as? [String: [String: String]] ?? [:]
        profiles[providerKey] = profile
        UserDefaults.standard.set(profiles, forKey: "localProfiles")
    }

    /// Looks up a previously-completed profile by provider user ID.
    private func loadLocalProfile(providerKey: String) -> (name: String, email: String, year: String)? {
        guard let profiles = UserDefaults.standard.dictionary(forKey: "localProfiles") as? [String: [String: String]],
              let profile = profiles[providerKey] else { return nil }
        return (
            name: profile["name"] ?? "Aggie Student",
            email: profile["email"] ?? "",
            year: profile["year"] ?? ""
        )
    }

    /// Sends auth credentials to the backend to get a backend JWT.
    /// Runs silently — failure doesn't block onboarding.
    private func registerWithBackend(displayName: String) async {
        do {
            let response: AuthResponse

            if let idToken = appleIdentityToken, let appleId = appleUserId {
                // Apple Sign-In flow
                response = try await UserAPIService.shared.authenticateWithApple(
                    identityToken: idToken,
                    appleUserId: appleId,
                    displayName: displayName,
                    email: email
                )
            } else if let idToken = googleIdToken, let gid = googleUserId {
                // Google Sign-In flow
                response = try await UserAPIService.shared.authenticateWithGoogle(
                    idToken: idToken,
                    googleUserId: gid,
                    displayName: displayName,
                    email: email
                )
            } else if let smsToken = AppState.shared.authToken {
                // Phone auth flow — use SMS auth token
                response = try await UserAPIService.shared.authenticateWithPhone(
                    phoneNumber: e164Phone,
                    smsToken: smsToken,
                    displayName: displayName
                )
            } else {
                return  // No auth credentials to send
            }

            if let token = response.token {
                AppState.shared.backendToken = token
                AppState.shared.persistStatePublic()
            }
        } catch {
            // Backend registration is best-effort — don't block the user
            print("Backend auth (non-blocking): \(error.localizedDescription)")
        }
    }

    // MARK: - Apple Sign-In

    func signInWithApple() async {
        isLoading = true
        errorMessage = nil

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        do {
            let credential = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>) in
                let delegate = AppleSignInDelegate(continuation: continuation)
                self.appleSignInDelegate = delegate

                let controller = ASAuthorizationController(authorizationRequests: [request])
                controller.delegate = delegate
                controller.presentationContextProvider = delegate
                controller.performRequests()
            }

            // Apple only returns name/email on first sign-in — extract if available
            if let fullName = credential.fullName {
                let name = [fullName.givenName, fullName.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                if !name.isEmpty {
                    displayName = name
                }
            }

            if let appleEmail = credential.email {
                email = appleEmail
            }

            // Store Apple credentials
            UserDefaults.standard.set(credential.user, forKey: "appleUserId")
            self.appleUserId = credential.user

            var tokenString: String?
            if let tokenData = credential.identityToken,
               let str = String(data: tokenData, encoding: .utf8) {
                self.appleIdentityToken = str
                tokenString = str
            }

            // Check backend — does this Apple ID already have an account?
            if let idToken = tokenString {
                do {
                    let backendResult = try await UserAPIService.shared.authenticateWithApple(
                        identityToken: idToken,
                        appleUserId: credential.user,
                        displayName: displayName,
                        email: email
                    )
                    if let token = backendResult.token {
                        AppState.shared.backendToken = token
                    }

                    if backendResult.isNewUser == false, let user = backendResult.user {
                        // Returning user found in backend
                        print("[Apple Auth] Returning user found in backend")
                        AppState.shared.currentUser = User(
                            name: user.username,
                            email: user.email,
                            year: nil
                        )
                        AppState.shared.isAuthenticated = true
                        AppState.shared.persistStatePublic()
                        appleSignInDelegate = nil
                        isLoading = false
                        return
                    }

                    print("[Apple Auth] Backend says new user (isNewUser=\(String(describing: backendResult.isNewUser)))")
                } catch {
                    print("[Apple Auth] Backend error: \(error.localizedDescription)")
                }
            }

            // Backend didn't recognize user or was unreachable —
            // check if we have a local profile from a previous session
            if let localProfile = loadLocalProfile(providerKey: credential.user) {
                print("[Apple Auth] Restoring from local profile cache")
                AppState.shared.currentUser = User(
                    name: localProfile.name,
                    email: localProfile.email,
                    year: localProfile.year
                )
                AppState.shared.isAuthenticated = true
                AppState.shared.persistStatePublic()
                appleSignInDelegate = nil
                isLoading = false
                return
            }

            // Truly new user — go to profile setup
            navigateTo(.profileSetup)
        } catch {
            let nsError = error as NSError
            // Don't show error if user cancelled
            if nsError.domain == ASAuthorizationError.errorDomain,
               nsError.code == ASAuthorizationError.canceled.rawValue {
                // User tapped cancel — do nothing
            } else {
                errorMessage = error.localizedDescription
            }
        }

        appleSignInDelegate = nil
        isLoading = false
    }

    // MARK: - Phone Auth

    func sendOTP() async {
        isLoading = true
        errorMessage = nil

        do {
            try await SMSAuthService.shared.sendCode(phoneNumber: e164Phone)
            navigateTo(.otpVerification)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func verifyOTP() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await SMSAuthService.shared.verifyCode(
                phoneNumber: e164Phone,
                code: otpCode
            )
            // Store SMS auth token
            AppState.shared.authToken = response.token
            AppState.shared.smsUserId = response.userId

            // Check backend — does this phone number already have an account?
            do {
                let backendResult = try await UserAPIService.shared.authenticateWithPhone(
                    phoneNumber: e164Phone,
                    smsToken: response.token
                )
                if let token = backendResult.token {
                    AppState.shared.backendToken = token
                }

                if backendResult.isNewUser == false, let user = backendResult.user {
                    // Returning user — skip profile setup, go straight to main app
                    AppState.shared.currentUser = User(
                        name: user.username,
                        email: user.email,
                        year: nil
                    )
                    AppState.shared.isAuthenticated = true
                    AppState.shared.persistStatePublic()
                    isLoading = false
                    return
                }
            } catch {
                print("OnboardingVM: backend phone auth check failed — \(error.localizedDescription)")
            }

            // New user or backend unavailable — go to profile setup
            navigateTo(.profileSetup)
        } catch {
            errorMessage = error.localizedDescription
            otpCode = ""
        }

        isLoading = false
    }

    // MARK: - Google Sign-In

    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil

        do {
            // Get the root view controller for presenting the Google Sign-In sheet
            guard let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first,
                  let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
                errorMessage = "Cannot present Google Sign-In"
                isLoading = false
                return
            }

            // Present Google Sign-In consent screen
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
            let user = result.user

            guard let idToken = user.idToken?.tokenString else {
                errorMessage = "Failed to get Google ID token"
                isLoading = false
                return
            }

            let googleId = user.userID ?? ""
            let fullName = user.profile?.name ?? ""
            let googleEmail = user.profile?.email ?? ""

            // Store credentials for profile setup flow
            self.googleIdToken = idToken
            self.googleUserId = googleId
            if !fullName.isEmpty { displayName = fullName }
            if !googleEmail.isEmpty { email = googleEmail }

            // Check backend — does this Google ID already have an account?
            do {
                let backendResult = try await UserAPIService.shared.authenticateWithGoogle(
                    idToken: idToken,
                    googleUserId: googleId,
                    displayName: displayName,
                    email: email
                )
                if let token = backendResult.token {
                    AppState.shared.backendToken = token
                }

                if backendResult.isNewUser == false, let existingUser = backendResult.user {
                    // Returning user found in backend
                    print("[Google Auth] Returning user found in backend")
                    AppState.shared.currentUser = User(
                        name: existingUser.username,
                        email: existingUser.email,
                        year: nil
                    )
                    AppState.shared.isAuthenticated = true
                    AppState.shared.persistStatePublic()
                    isLoading = false
                    return
                }

                print("[Google Auth] Backend says new user (isNewUser=\(String(describing: backendResult.isNewUser)))")
            } catch {
                print("[Google Auth] Backend error: \(error.localizedDescription)")
            }

            // Backend didn't recognize user or was unreachable —
            // check if we have a local profile from a previous session
            if let localProfile = loadLocalProfile(providerKey: googleId) {
                print("[Google Auth] Restoring from local profile cache")
                AppState.shared.currentUser = User(
                    name: localProfile.name,
                    email: localProfile.email,
                    year: localProfile.year
                )
                AppState.shared.isAuthenticated = true
                AppState.shared.persistStatePublic()
                isLoading = false
                return
            }

            // Truly new user — go to profile setup
            navigateTo(.profileSetup)
        } catch {
            let nsError = error as NSError
            // GIDSignIn cancellation error code
            if nsError.domain == "com.google.GIDSignIn" && nsError.code == -5 {
                // User tapped cancel — do nothing
            } else {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }
}

// MARK: - Apple Sign-In Delegate

/// Bridges ASAuthorizationController delegate callbacks to async/await via CheckedContinuation.
private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?

    init(continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>) {
        self.continuation = continuation
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
            continuation?.resume(returning: credential)
            continuation = nil
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
        if let window = scene?.windows.first(where: { $0.isKeyWindow }) {
            return window
        }
        return UIWindow(windowScene: scene!)
    }
}
