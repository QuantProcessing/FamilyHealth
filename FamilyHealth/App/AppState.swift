import SwiftUI

/// Global application state shared across the app
final class AppState: ObservableObject {
    /// Current running mode
    @Published var mode: AppMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: "app_mode") }
    }

    /// Whether the user has completed onboarding
    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "onboarding_done") }
    }

    /// Current logged-in user ID (nil if not logged in)
    @Published var currentUserId: String? {
        didSet { UserDefaults.standard.set(currentUserId, forKey: "current_user_id") }
    }

    /// Server URL for remote mode
    @Published var serverURL: String {
        didSet { UserDefaults.standard.set(serverURL, forKey: "server_url") }
    }

    var isLoggedIn: Bool { currentUserId != nil }

    init() {
        let modeStr = UserDefaults.standard.string(forKey: "app_mode") ?? AppMode.local.rawValue
        self.mode = AppMode(rawValue: modeStr) ?? .local
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "onboarding_done")
        self.currentUserId = UserDefaults.standard.string(forKey: "current_user_id")
        self.serverURL = UserDefaults.standard.string(forKey: "server_url") ?? ""
    }

    func logout() {
        currentUserId = nil
    }
}

/// Running mode: local (offline) or remote (cloud)
enum AppMode: String, Codable, CaseIterable {
    case local
    case remote

    var displayName: String {
        switch self {
        case .local: return String(localized: "本地模式")
        case .remote: return String(localized: "联网模式")
        }
    }
}
