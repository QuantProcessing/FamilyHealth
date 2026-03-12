import SwiftUI
import SwiftData

/// Root view — shows onboarding on first launch, then main app
struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var context
    @Query private var aiConfigs: [AIModelConfig]

    var body: some View {
        Group {
            if !appState.hasCompletedOnboarding {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut, value: appState.hasCompletedOnboarding)
        .onAppear {
            ensureDefaultUser()
            ensureBuiltInAIModel()
        }
    }

    /// Auto-create a default local user on first launch
    private func ensureDefaultUser() {
        guard appState.currentUserId == nil else { return }
        let user = User(phone: "", name: "用户", gender: .male)
        context.insert(user)
        try? context.save()
        appState.currentUserId = user.id.uuidString
    }

    /// Auto-create the built-in free AI model config on first launch
    private func ensureBuiltInAIModel() {
        guard !aiConfigs.contains(where: { $0.isBuiltIn }) else { return }

        let config = AIModelConfig(
            name: "免费模型 (InternLM)",
            provider: .siliconflow,
            apiEndpoint: AIModelConfig.Provider.siliconflow.defaultEndpoint,
            modelName: AIModelConfig.Provider.siliconflow.defaultModel,
            isDefault: aiConfigs.isEmpty,
            isBuiltIn: true
        )
        context.insert(config)
        // Store the built-in API key in Keychain
        try? KeychainManager.saveAPIKey(AIModelConfig.builtInAPIKey, for: config.id)
        try? context.save()
    }
}
