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

    // Use AppState.shared so the onboarding ViewModel and the
    // app gate both observe the exact same instance.
    @StateObject private var appState = AppState.shared
    @State private var isCheckingSession = true
    @State private var needsForceUpdate = false

    // MARK: - Debug Flags
    // Set to true to force onboarding screen on launch (keeps your account intact)
    private let forceOnboarding = false
    // Set to true to replay all onboarding tips on next launch
    private let resetTips = false

    var body: some Scene {
        WindowGroup {
            Group {
                if isCheckingSession {
                    // Brief splash while validating session
                    ZStack {
                        Color(.systemBackground).ignoresSafeArea()
                        ProgressView()
                    }
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
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
            .task {
                if resetTips { OnboardingManager.shared.resetAllTips() }
                // Check for required update before showing any UI
                needsForceUpdate = await AppUpdateService.shared.isUpdateRequired()
                guard !needsForceUpdate else { return }
                await appState.restoreSession()
                isCheckingSession = false
                // Schedule daily DailyFive reminders (refreshes the 7-day window each launch)
                await NotificationService.shared.scheduleDailyFiveReminders()
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
