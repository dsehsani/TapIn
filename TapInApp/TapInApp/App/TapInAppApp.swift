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

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
        }
        application.registerForRemoteNotifications()
        return true
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

    var body: some Scene {
        WindowGroup {
            Group {
                if isCheckingSession {
                    // Brief splash while validating session
                    ZStack {
                        Color(.systemBackground).ignoresSafeArea()
                        ProgressView()
                    }
                } else if appState.isAuthenticated {
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
                await appState.restoreSession()
                isCheckingSession = false
            }
            .preferredColorScheme(appState.darkModeEnabled ? .dark : nil)
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
