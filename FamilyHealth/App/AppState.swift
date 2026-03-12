import SwiftUI

/// Global application state shared across the app
final class AppState: ObservableObject {
    /// Current user ID (auto-created on first launch)
    @Published var currentUserId: String? {
        didSet { UserDefaults.standard.set(currentUserId, forKey: "current_user_id") }
    }

    var isLoggedIn: Bool { currentUserId != nil }

    init() {
        self.currentUserId = UserDefaults.standard.string(forKey: "current_user_id")
    }

    func logout() {
        currentUserId = nil
    }
}
