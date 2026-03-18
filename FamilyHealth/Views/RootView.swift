import SwiftUI
import SwiftData

/// Root view — shows onboarding on first launch, then main app
struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var context
    @Query private var aiConfigs: [AIModelConfig]

    @AppStorage("hasAcknowledgedDisclaimer") private var hasAcknowledgedDisclaimer = false
    @State private var showDisclaimer = false

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
            if !hasAcknowledgedDisclaimer && appState.hasCompletedOnboarding {
                showDisclaimer = true
            }
        }
        .alert("重要提示", isPresented: $showDisclaimer) {
            Button("我已了解") {
                hasAcknowledgedDisclaimer = true
            }
        } message: {
            Text("本应用为个人开源项目，AI 分析结果仅供参考，不能替代专业医疗诊断。\n\n身体不适请务必及时就医，以医生的诊断为准。")
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
