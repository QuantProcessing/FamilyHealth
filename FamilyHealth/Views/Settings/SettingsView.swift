import SwiftUI
import SwiftData

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            List {
                // Profile header
                Section {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(Color(.systemGray4))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text("用户")
                                .font(.title3.bold())
                            Text(appState.mode.displayName)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(.green.opacity(0.1))
                                .foregroundStyle(.green)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Account
                Section("账户") {
                    NavigationLink {
                        Text("个人资料") // TODO: ProfileEditView
                    } label: {
                        Label("个人资料", systemImage: "person.circle")
                    }

                    NavigationLink {
                        ModeSettingsView()
                    } label: {
                        Label("运行模式", systemImage: "globe")
                    }
                }

                // AI Config
                Section("AI 配置") {
                    NavigationLink {
                        AIModelSettingsView()
                    } label: {
                        HStack {
                            Label("AI 模型设置", systemImage: "cpu")
                            Spacer()
                        }
                    }
                }

                // General
                Section("通用") {
                    NavigationLink {
                        Text("语言设置") // TODO
                    } label: {
                        HStack {
                            Label("语言 Language", systemImage: "globe")
                            Spacer()
                            Text("简体中文")
                                .foregroundStyle(.secondary)
                        }
                    }

                    NavigationLink {
                        Text("数据管理") // TODO
                    } label: {
                        Label("数据管理", systemImage: "externaldrive")
                    }
                }

                // About
                Section("关于") {
                    HStack {
                        Label("版本", systemImage: "info.circle")
                        Spacer()
                        Text("v1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    NavigationLink { Text("隐私政策") } label: {
                        Label("隐私政策", systemImage: "hand.raised")
                    }

                    NavigationLink { Text("使用帮助") } label: {
                        Label("使用帮助", systemImage: "questionmark.circle")
                    }
                }

                // Logout
                Section {
                    Button(role: .destructive) {
                        appState.logout()
                    } label: {
                        Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("设置")
        }
    }
}

// MARK: - Mode Settings
struct ModeSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var serverURL = ""
    @State private var syncLocalData = false

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: appState.mode == .local ? "iphone" : "cloud")
                        .font(.title2)
                        .foregroundStyle(.green)
                    VStack(alignment: .leading) {
                        Text("当前：\(appState.mode.displayName)")
                            .font(.headline)
                        Text(appState.mode == .local ?
                             "所有数据存储在设备本地，无需联网" :
                             "数据同步至云端服务器")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            if appState.mode == .local {
                Section("切换到联网模式") {
                    TextField("服务端地址", text: $serverURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)

                    Button("测试连接") {
                        // TODO: test connection
                    }

                    Toggle("上传本地数据到云端", isOn: $syncLocalData)

                    Text("切换后，新数据将直接存储到云端")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Section {
                    Button("确认切换") {
                        appState.serverURL = serverURL
                        appState.mode = .remote
                    }
                    .disabled(serverURL.isEmpty)
                }
            } else {
                Section {
                    Button("切换到本地模式") {
                        appState.mode = .local
                    }
                }
            }
        }
        .navigationTitle("运行模式")
        .onAppear { serverURL = appState.serverURL }
    }
}

// MARK: - AI Model Settings
struct AIModelSettingsView: View {
    @Query private var configs: [AIModelConfig]
    @State private var showAddSheet = false

    var body: some View {
        List {
            ForEach(configs) { config in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(config.name)
                                .font(.headline)
                            if config.isDefault {
                                Text("默认")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.blue)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                            }
                        }
                        Text(config.provider.displayName + " · " + config.modelName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(config.apiEndpoint)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }

            Button {
                showAddSheet = true
            } label: {
                Label("添加新模型", systemImage: "plus")
            }
        }
        .navigationTitle("AI 模型设置")
        .sheet(isPresented: $showAddSheet) {
            AddAIModelView()
        }
    }
}

// MARK: - Add AI Model
struct AddAIModelView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var provider: AIModelConfig.Provider = .openai
    @State private var apiEndpoint = ""
    @State private var apiKey = ""
    @State private var modelName = ""
    @State private var isDefault = false
    @State private var testResult: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("配置名称", text: $name)

                    Picker("提供商", selection: $provider) {
                        ForEach(AIModelConfig.Provider.allCases, id: \.self) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                }

                Section("API 配置") {
                    TextField("API 地址", text: $apiEndpoint)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)

                    SecureField("API Key", text: $apiKey)

                    TextField("模型名称（如 gpt-4o）", text: $modelName)
                        .textInputAutocapitalization(.never)
                }

                Section {
                    Button("测试连接") {
                        testResult = "连接测试功能将在 M4 实现"
                    }
                    if let result = testResult {
                        Text(result)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Toggle("设为默认模型", isOn: $isDefault)
                }
            }
            .navigationTitle("添加模型")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(name.isEmpty || apiEndpoint.isEmpty || apiKey.isEmpty || modelName.isEmpty)
                }
            }
        }
    }

    private func save() {
        let config = AIModelConfig(
            name: name,
            provider: provider,
            apiEndpoint: apiEndpoint,
            modelName: modelName,
            isDefault: isDefault
        )
        context.insert(config)

        // Save API key to Keychain
        try? KeychainManager.saveAPIKey(apiKey, for: config.id)

        dismiss()
    }
}
