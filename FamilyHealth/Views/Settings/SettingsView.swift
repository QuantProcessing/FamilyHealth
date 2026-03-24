import SwiftUI
import SwiftData

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Query private var allUsers: [User]

    private var currentUser: User? {
        guard let id = appState.currentUserId, let uuid = UUID(uuidString: id) else { return nil }
        return allUsers.first(where: { $0.id == uuid })
    }

    var body: some View {
        NavigationStack {
            List {
                // Profile header
                Section {
                    NavigationLink {
                        ProfileEditView()
                    } label: {
                        HStack(spacing: FHSpacing.lg) {
                            Circle()
                                .fill(FHGradients.profileAvatar)
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.title2)
                                        .foregroundStyle(.white)
                                )
                                .fhShadow(.light)

                            VStack(alignment: .leading, spacing: FHSpacing.xs) {
                                Text(currentUser?.name ?? "用户")
                                    .font(.title3.bold())
                                Text("点击编辑个人资料")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, FHSpacing.xs)
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
                        DataManagementView()
                    } label: {
                        Label("数据管理", systemImage: "externaldrive")
                    }
                }


                // About
                Section("关于") {
                    NavigationLink { AboutView() } label: {
                        HStack {
                            Label("关于家庭健康AI版", systemImage: "info.circle")
                            Spacer()
                            Text("v1.0.1")
                                .foregroundStyle(.secondary)
                        }
                    }
                }


            }
            .navigationTitle("设置")
        }
    }
}


// MARK: - AI Model Settings
struct AIModelSettingsView: View {
    @Query private var configs: [AIModelConfig]
    @Environment(\.modelContext) private var context
    @State private var showAddSheet = false

    var body: some View {
        List {
            if configs.isEmpty {
                Section {
                    Text("尚未添加任何 AI 模型")
                        .foregroundStyle(.secondary)
                }
            }

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
                                    .background(FHColors.primary)
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
                .contextMenu {
                    if !config.isDefault {
                        Button {
                            setAsDefault(config)
                        } label: {
                            Label("设为默认", systemImage: "checkmark.circle")
                        }
                    }
                    Button(role: .destructive) {
                        deleteConfig(config)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        deleteConfig(config)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    if !config.isDefault {
                        Button {
                            setAsDefault(config)
                        } label: {
                            Label("默认", systemImage: "checkmark.circle")
                        }
                        .tint(FHColors.primary)
                    }
                }
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

    private func setAsDefault(_ config: AIModelConfig) {
        for c in configs { c.isDefault = false }
        config.isDefault = true
        try? context.save()
    }

    private func deleteConfig(_ config: AIModelConfig) {
        try? KeychainManager.deleteAPIKey(for: config.id)
        let wasDefault = config.isDefault
        context.delete(config)
        try? context.save()
        if wasDefault, let first = configs.first {
            first.isDefault = true
            try? context.save()
        }
    }
}

// MARK: - Add AI Model
struct AddAIModelView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var existingConfigs: [AIModelConfig]

    @State private var name = ""
    @State private var provider: AIModelConfig.Provider = .deepseek
    @State private var apiEndpoint = ""
    @State private var apiKey = ""
    @State private var modelName = ""
    @State private var isDefault = false
    @State private var useBuiltIn = false
    @State private var testResult: String?
    @State private var testPassed = false
    @State private var isTesting = false

    var body: some View {
        NavigationStack {
            Form {
                Section("选择 AI 模型") {
                    Picker("提供商", selection: $provider) {
                        ForEach(AIModelConfig.Provider.allCases, id: \.self) { p in
                            Label(p.displayName, systemImage: p.iconName).tag(p)
                        }
                    }
                    .onChange(of: provider) { _, newVal in
                        name = newVal.displayName
                        apiEndpoint = newVal.defaultEndpoint
                        modelName = newVal.defaultModel
                        testPassed = false
                        testResult = nil
                    }

                    TextField("配置名称", text: $name)
                }

                if provider != .custom {
                    Section {
                        Toggle("使用内置代理（免费）", isOn: $useBuiltIn)
                    } footer: {
                        Text(useBuiltIn ? "无需 API Key，通过 FamilyHealth 服务器转发" : "使用自己的 API Key 直接调用")
                    }
                }

                if !useBuiltIn || provider == .custom {
                    Section("API 配置") {
                        TextField("API 地址", text: $apiEndpoint)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .onChange(of: apiEndpoint) { _, _ in testPassed = false }

                        SecureField("API Key", text: $apiKey)
                            .onChange(of: apiKey) { _, _ in testPassed = false }

                        TextField("模型名称", text: $modelName)
                            .textInputAutocapitalization(.never)
                            .onChange(of: modelName) { _, _ in testPassed = false }
                    }

                    Section {
                        Button {
                            runTest()
                        } label: {
                            HStack {
                                if isTesting {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("测试中...")
                                } else {
                                    Label("测试连接", systemImage: testPassed ? "checkmark.circle.fill" : "bolt.horizontal")
                                }
                            }
                        }
                        .disabled(apiEndpoint.isEmpty || apiKey.isEmpty || modelName.isEmpty || isTesting)

                        if let result = testResult {
                            Text(result)
                                .font(.caption)
                                .foregroundStyle(testPassed ? FHColors.success : FHColors.danger)
                        }
                    } footer: {
                        Text("必须通过连接测试后才能保存模型")
                            .font(.caption2)
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
                        .disabled(name.isEmpty || (!useBuiltIn && !testPassed))
                }
            }
            .onAppear {
                name = provider.displayName
                apiEndpoint = provider.defaultEndpoint
                modelName = provider.defaultModel
            }
        }
    }

    private func runTest() {
        isTesting = true
        testResult = nil
        testPassed = false

        Task {
            do {
                let client = AIClient()
                let success = try await client.testConnection(
                    endpoint: apiEndpoint, apiKey: apiKey, model: modelName)
                testResult = success ? "✅ 连接成功，可以保存" : "❌ 连接失败"
                testPassed = success
            } catch {
                testResult = "❌ \(error.localizedDescription)"
                testPassed = false
            }
            isTesting = false
        }
    }

    private func save() {
        let shouldBeDefault = isDefault || existingConfigs.isEmpty
        if shouldBeDefault {
            for c in existingConfigs { c.isDefault = false }
        }

        let isBI = useBuiltIn && provider != .custom
        let endpoint = isBI ? AIModelConfig.proxyEndpoint : apiEndpoint

        let config = AIModelConfig(
            name: name,
            provider: provider,
            apiEndpoint: endpoint,
            modelName: modelName,
            isDefault: shouldBeDefault,
            isBuiltIn: isBI
        )
        context.insert(config)
        if !isBI {
            try? KeychainManager.saveAPIKey(apiKey, for: config.id)
        }
        try? context.save()

        dismiss()
    }
}

// MARK: - Profile Edit

struct ProfileEditView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allUsers: [User]
    @State private var name = ""
    @State private var gender: User.Gender = .male
    @State private var birthDate: Date = Date()
    @State private var hasBirthDate = false
    @State private var heightCm: String = ""
    @State private var weightKg: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""

    private var currentUser: User? {
        guard let id = appState.currentUserId, let uuid = UUID(uuidString: id) else { return nil }
        return allUsers.first(where: { $0.id == uuid })
    }

    private var bmi: String? {
        guard let h = Double(heightCm), let w = Double(weightKg), h > 0 else { return nil }
        let bmiVal = w / ((h / 100) * (h / 100))
        return String(format: "%.1f", bmiVal)
    }

    var body: some View {
        Form {
            Section("基本信息") {
                HStack {
                    Text("姓名")
                    Spacer()
                    TextField("请输入姓名", text: $name)
                        .multilineTextAlignment(.trailing)
                }
                Picker("性别", selection: $gender) {
                    ForEach(User.Gender.allCases, id: \.self) { g in
                        Text(g.displayName).tag(g)
                    }
                }
            }

            Section("出生日期") {
                Toggle("设置出生日期", isOn: $hasBirthDate)
                if hasBirthDate {
                    DatePicker("出生日期", selection: $birthDate, displayedComponents: .date)
                }
            }

            Section {
                HStack {
                    Text("身高 (cm)")
                    Spacer()
                    TextField("170", text: $heightCm)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
                HStack {
                    Text("体重 (kg)")
                    Spacer()
                    TextField("65", text: $weightKg)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
                if let bmi = bmi {
                    HStack {
                        Text("BMI")
                        Spacer()
                        Text(bmi)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("身体数据")
            }
        }
        .navigationTitle("个人资料")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { saveProfile() }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear { loadUser() }
        .swAlert(isPresented: $showAlert, type: .success, message: alertMessage)
    }

    private func loadUser() {
        guard let user = currentUser else { return }
        name = user.name
        gender = user.gender
        if let bd = user.birthDate {
            birthDate = bd
            hasBirthDate = true
        }
        if let h = user.height { heightCm = String(format: "%.0f", h) }
        if let w = user.weight { weightKg = String(format: "%.1f", w) }
    }

    private func saveProfile() {
        guard let user = currentUser else { return }
        user.name = name.trimmingCharacters(in: .whitespaces)
        user.gender = gender
        user.birthDate = hasBirthDate ? birthDate : nil
        user.height = Double(heightCm)
        user.weight = Double(weightKg)
        user.updatedAt = Date()
        try? context.save()

        alertMessage = "已保存"
        showAlert = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { dismiss() }
    }
}


// MARK: - About

struct AboutView: View {
    var body: some View {
        List {
            // App info header
            Section {
                VStack(spacing: FHSpacing.lg) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(FHColors.primary)

                    Text("家庭健康AI版")
                        .font(.title2.bold())
                    Text("版本 1.0.1")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, FHSpacing.lg)
            }

            // Open source notice
            Section {
                VStack(alignment: .leading, spacing: FHSpacing.md) {
                    Label("开源项目", systemImage: "lock.open")
                        .font(.headline)
                    Text("本应用为个人开源项目，源代码公开透明。欢迎参与贡献和反馈。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, FHSpacing.sm)

                Button {
                    if let url = URL(string: "https://github.com/QuantProcessing/FamilyHealth") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("GitHub 仓库", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            }

            // Medical disclaimer
            Section {
                VStack(alignment: .leading, spacing: FHSpacing.md) {
                    Label("免责声明", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(.orange)
                    Text("本应用提供的 AI 分析结果仅供参考，不构成任何医疗建议。AI 生成的内容可能存在误差，不能替代专业医疗诊断。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("如有身体不适，请务必及时前往医院就诊，以专业医生的诊断和治疗方案为准。")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                }
                .padding(.vertical, FHSpacing.sm)
            }

            // Links
            Section("更多") {
                NavigationLink { PrivacyPolicyView() } label: {
                    Label("隐私政策", systemImage: "hand.raised")
                }
                NavigationLink { HelpView() } label: {
                    Label("使用帮助", systemImage: "questionmark.circle")
                }
                Button {
                    if let url = URL(string: "https://quantprocessing.github.io/FamilyHealth/support.html") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("技术支持", systemImage: "wrench.and.screwdriver")
                }
            }
        }
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Data Management

struct DataManagementView: View {
    @Query private var reports: [HealthReport]
    @Query private var cases: [MedicalCase]
    @Query private var conversations: [ChatConversation]
    @Environment(\.modelContext) private var context
    @State private var showClearConfirm = false
    @State private var storageSize = "计算中..."
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        List {
            Section("数据统计") {
                HStack {
                    Label("体检报告", systemImage: "doc.text")
                    Spacer()
                    Text("\(reports.count) 份").foregroundStyle(.secondary)
                }
                HStack {
                    Label("病例记录", systemImage: "list.clipboard")
                    Spacer()
                    Text("\(cases.count) 份").foregroundStyle(.secondary)
                }
                HStack {
                    Label("AI 对话", systemImage: "bubble.left.and.bubble.right")
                    Spacer()
                    Text("\(conversations.count) 个").foregroundStyle(.secondary)
                }
            }

            Section("存储空间") {
                HStack {
                    Label("报告文件", systemImage: "internaldrive")
                    Spacer()
                    Text(storageSize).foregroundStyle(.secondary)
                }
            }

            Section {
                Button(role: .destructive) {
                    showClearConfirm = true
                } label: {
                    Label("清除所有健康数据", systemImage: "trash")
                }
            } footer: {
                Text("清除后无法恢复，请谨慎操作。此操作不会删除 AI 模型配置和账户信息。")
            }
        }
        .navigationTitle("数据管理")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { calculateStorage() }
        .confirmationDialog("清除所有数据", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("确认清除", role: .destructive) { clearAllData() }
        } message: {
            Text("将删除所有体检报告、病例记录和 AI 对话历史，此操作不可撤销。")
        }
        .swAlert(isPresented: $showAlert, type: .success, message: alertMessage)
    }

    private func calculateStorage() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let reportsDir = documentsURL.appendingPathComponent("reports")
        var totalSize: Int64 = 0
        if let enumerator = FileManager.default.enumerator(at: reportsDir, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let url as URL in enumerator {
                if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(size)
                }
            }
        }
        if totalSize < 1024 {
            storageSize = "\(totalSize) B"
        } else if totalSize < 1024 * 1024 {
            storageSize = String(format: "%.1f KB", Double(totalSize) / 1024)
        } else {
            storageSize = String(format: "%.1f MB", Double(totalSize) / 1024 / 1024)
        }
    }

    private func clearAllData() {
        for r in reports { context.delete(r) }
        for c in cases { context.delete(c) }
        for conv in conversations { context.delete(conv) }
        try? context.save()

        // Delete report files
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let reportsDir = documentsURL.appendingPathComponent("reports")
        try? FileManager.default.removeItem(at: reportsDir)

        alertMessage = "已清除所有数据"
        showAlert = true
        calculateStorage()
    }
}

// MARK: - Privacy Policy

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FHSpacing.lg) {
                Text("最后更新：2025 年 12 月")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                policySection("1. 数据收集",
                    "FamilyHealth 采用**本地优先**架构。在本地模式下，所有数据（体检报告、病例记录、AI 对话）均存储在您的设备上，不会上传至任何服务器。\n\n在联网模式下，数据将同步至您自己部署的后端服务器。")

                policySection("2. AI 功能",
                    "AI 功能使用您自行配置的 API 服务（如 DeepSeek、硅基流动等）。当您使用 AI 对话或报告分析时，相关文本数据会发送至您配置的 API 端点。\n\n**我们不存储或转发您的 API 密钥和对话数据。** API 密钥使用 iOS Keychain 安全存储。")

                policySection("3. 健康数据",
                    "体检报告图片和 PDF 文件存储在应用沙盒的 Documents 目录中。文本提取（OCR）在设备本地完成，提取的文本仅用于 AI 分析，不会外传。")

                policySection("4. 家庭组",
                    "在本地模式下，家庭组功能仅在同一设备上生效。QR 邀请码不包含敏感信息。在联网模式下，家庭成员数据通过您的后端服务器管理。")

                policySection("5. 第三方服务",
                    "本应用不包含任何第三方 SDK、广告或分析工具。不会向任何第三方分享您的数据。")

                policySection("6. 您的权利",
                    "您可以随时在「设置 → 数据管理」中删除所有健康数据。删除操作不可逆。\n\n卸载应用将永久删除所有本地数据。")

                policySection("7. 联系方式",
                    "如有隐私相关问题，请通过应用内「使用帮助」页面联系我们。")
            }
            .padding()
        }
        .navigationTitle("隐私政策")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func policySection(_ title: String, _ content: String) -> some View {
        VStack(alignment: .leading, spacing: FHSpacing.sm) {
            Text(title)
                .font(.headline)
            Text(.init(content))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Help

struct HelpView: View {
    @State private var expandedSection: String?

    private let faqs: [(icon: String, title: String, items: [(q: String, a: String)])] = [
        ("doc.text", "体检报告", [
            ("如何上传体检报告？", "点击首页「上传报告」或档案页右下角 + 按钮，支持拍照、从相册选择照片或从文件导入 PDF。"),
            ("AI 分析需要多久？", "取决于您配置的 AI 模型和网络速度，通常 5-30 秒。分析结果会自动保存在报告详情中。"),
            ("PDF 报告如何提取文字？", "上传时会自动提取 PDF 中的文字内容。如果是扫描件，会使用 OCR 技术识别文字。"),
        ]),
        ("brain.head.profile", "AI 助手", [
            ("如何配置 AI 模型？", "进入「设置 → AI 模型设置」，点击 + 号添加模型。支持 DeepSeek、硅基流动、通义千问等主流 API 服务。"),
            ("为什么 AI 没有回复？", "请检查：1) API 地址和密钥是否正确（可点击测试按钮）2) 网络连接是否正常 3) 余额是否充足。"),
            ("AI 能分析什么？", "AI 可以分析您的体检报告指标、提供健康建议、解答医学问题。请注意 AI 建议仅供参考，不能替代医生诊断。"),
        ]),
        ("person.3", "家庭管理", [
            ("如何添加家庭成员？", "在家庭组详情中点击「添加成员」，填写姓名和基本信息即可。"),
            ("可以加入几个家庭组？", "没有数量限制，您可以根据需要创建或加入多个家庭组。"),
            ("管理员可以看到成员的什么数据？", "管理员可以查看成员的体检报告。病例记录和 AI 对话属于个人隐私，不可查看。"),
        ]),
        ("lock.shield", "数据安全", [
            ("数据存储在哪里？", "本地模式下所有数据存储在您的 iPhone 上。联网模式下同步至您自己部署的服务器。"),
            ("API 密钥安全吗？", "API 密钥使用 iOS Keychain 加密存储，与银行卡信息同级别的安全保护。"),
            ("如何删除所有数据？", "进入「设置 → 数据管理」，点击「清除所有健康数据」。"),
        ]),
    ]

    var body: some View {
        List {
            ForEach(faqs, id: \.title) { section in
                Section {
                    ForEach(section.items, id: \.q) { item in
                        DisclosureGroup(
                            isExpanded: Binding(
                                get: { expandedSection == item.q },
                                set: { expandedSection = $0 ? item.q : nil }
                            )
                        ) {
                            Text(item.a)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, FHSpacing.xs)
                        } label: {
                            Text(item.q)
                                .font(.subheadline)
                        }
                    }
                } header: {
                    Label(section.title, systemImage: section.icon)
                }
            }

            Section("联系我们") {
                VStack(alignment: .leading, spacing: FHSpacing.sm) {
                    Text("如有其他问题，请联系开发者：")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Label("feedback@familyhealth.app", systemImage: "envelope")
                        .font(.subheadline)
                }
                .padding(.vertical, FHSpacing.xs)
            }
        }
        .navigationTitle("使用帮助")
        .navigationBarTitleDisplayMode(.inline)
    }
}
