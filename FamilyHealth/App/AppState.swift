import SwiftUI

/// Global application state shared across the app
final class AppState: ObservableObject {
    /// Whether the user has completed onboarding
    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "onboarding_done") }
    }

    /// Current logged-in user ID (nil if not logged in)
    @Published var currentUserId: String? {
        didSet { UserDefaults.standard.set(currentUserId, forKey: "current_user_id") }
    }

    var isLoggedIn: Bool { currentUserId != nil }

    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "onboarding_done")
        self.currentUserId = UserDefaults.standard.string(forKey: "current_user_id")
    }

    func logout() {
        currentUserId = nil
    }
}
