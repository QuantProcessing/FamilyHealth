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

// MARK: - Build Configuration

/// Compile-time build configuration.
/// Add `SERVER_MODE` to Active Compilation Conditions via xcconfig to enable server features.
///
/// - Local mode (default): All data local, no server, no built-in AI proxy
/// - Server mode: Server registration/login, built-in AI proxy, data still local
enum BuildConfig {
    #if SERVER_MODE
    static let isServerMode = true
    #else
    static let isServerMode = false
    #endif

    /// Server URL (only used in SERVER_MODE builds)
    static var serverURL: String {
        #if SERVER_MODE
        if let url = Bundle.main.infoDictionary?["SERVER_URL"] as? String, !url.isEmpty {
            return url
        }
        return "http://localhost:8080"
        #else
        return ""
        #endif
    }
}
