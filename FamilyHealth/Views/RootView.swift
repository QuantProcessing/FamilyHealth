import SwiftUI

/// Root view that manages navigation between onboarding and main app
struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if !appState.hasCompletedOnboarding {
                OnboardingView()
            } else if !appState.isLoggedIn {
                LoginView()
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut, value: appState.hasCompletedOnboarding)
        .animation(.easeInOut, value: appState.isLoggedIn)
    }
}
