//
//  TapInAppApp.swift
//  TapInApp
//
//  Main entry point for the TapIn UC Davis News App
//  MVVM Architecture with SwiftUI
//

import SwiftUI
import GoogleSignIn
import FirebaseCore
import FirebaseAuth
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
        }
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()
        return true
    }

    // Show local notification banners even when the app is in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Auth.auth().setAPNSToken(deviceToken, type: .unknown)
    }

    nonisolated func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        if Auth.auth().canHandleNotification(userInfo) {
            return .noData
        }
        return .newData
    }
}

@main
struct TapInAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @Environment(\.scenePhase) private var scenePhase

    // Use AppState.shared so the onboarding ViewModel and the
    // app gate both observe the exact same instance.
    @StateObject private var appState = AppState.shared
    @State private var isCheckingSession = true
    @State private var needsForceUpdate = false

    // MARK: - Debug Flags
    // Set to true to force onboarding screen on launch (keeps your account intact)
    private let forceOnboarding = false

    var body: some Scene {
        WindowGroup {
            Group {
                if isCheckingSession {
                    SplashView()
                } else if needsForceUpdate {
                    ForceUpdateView()
                } else if appState.isAuthenticated && !forceOnboarding {
                    ContentView()
                        .environmentObject(appState)
                } else {
                    OnboardingView()
                        .environmentObject(appState)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: isCheckingSession)
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
            .task {
                // One-time cleanup of removed onboarding tip keys
                let tipCleanupKey = "onboarding_tips_removed_v1"
                if !UserDefaults.standard.bool(forKey: tipCleanupKey) {
                    let keysToRemove = [
                        "onboarding_tip_dismissed_categoryPills",
                        "onboarding_tip_dismissed_featuredGame",
                        "tutorial_seen_wordle",
                        "tutorial_seen_pipes",
                        "tutorial_seen_echo",
                    ]
                    for key in keysToRemove {
                        UserDefaults.standard.removeObject(forKey: key)
                    }
                    UserDefaults.standard.set(true, forKey: tipCleanupKey)
                }
                // Run update check and session restore in parallel
                async let updateRequired = AppUpdateService.shared.isUpdateRequired()
                if !appState.isGuestMode {
                    async let sessionRestore: Void = appState.restoreSession()
                    needsForceUpdate = await updateRequired
                    _ = await sessionRestore
                } else {
                    needsForceUpdate = await updateRequired
                }
                withAnimation { isCheckingSession = false }
                // Only schedule reminders for signed-in users (not guests)
                if appState.isAuthenticated && !appState.isGuestMode && !needsForceUpdate {
                    await NotificationService.shared.schedulePipesGiveawayReminders()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active && !isCheckingSession {
                    Task {
                        needsForceUpdate = await AppUpdateService.shared.isUpdateRequired()
                        if !appState.isGuestMode {
                            async let drain: Void = LikeSyncQueue.shared.drain()
                            async let refresh: Void = SocialService.shared.refreshAllCachedLikes()
                            _ = await (drain, refresh)
                        }
                    }
                }
            }
            .alert(
                appState.globalError?.title ?? "Error",
                isPresented: $appState.showErrorAlert,
                presenting: appState.globalError
            ) { _ in
                Button("OK") { appState.clearError() }
            } message: { error in
                Text(error.errorDescription ?? "An unknown error occurred.")
            }
        }
    }
}
