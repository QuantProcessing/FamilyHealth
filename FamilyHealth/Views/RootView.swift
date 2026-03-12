import SwiftUI
import SwiftData

/// Root view — auto-creates a default user on first launch, then shows main app
struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var context

    var body: some View {
        MainTabView()
            .onAppear {
                ensureDefaultUser()
            }
    }

    /// Auto-create a default local user on first launch
    private func ensureDefaultUser() {
        guard appState.currentUserId == nil else { return }

        let user = User(
            phone: "",
            name: "用户",
            gender: .male
        )
        context.insert(user)
        try? context.save()
        appState.currentUserId = user.id.uuidString
    }
}
