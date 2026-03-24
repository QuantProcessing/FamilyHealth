import SwiftUI
import SwiftData

/// AI Chat conversation view with streaming messages
struct AIChatView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var appState: AppState
    @Query private var aiConfigs: [AIModelConfig]
    @Query private var allUsers: [User]
    @Query private var allMembers: [FamilyMember]

    let conversationId: UUID?
    var forUserId: UUID? = nil
    @State private var conversation: ChatConversation?
    @State private var inputText = ""
    @State private var isStreaming = false
    @State private var streamedContent = ""
    @State private var showAlert = false
    @State private var alertType: SWAlertType = .error
    @State private var alertMessage = ""
    @State private var scrollProxy: ScrollViewProxy?
    @State private var showMentionPicker = false

    private var defaultConfig: AIModelConfig? {
        aiConfigs.first(where: \.isDefault) ?? aiConfigs.first
    }

    private var sortedMessages: [ChatMessage] {
        (conversation?.messages ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        Group {
            if defaultConfig == nil {
                // No AI config — show setup prompt
                VStack(spacing: FHSpacing.lg) {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(FHColors.aiPurple.opacity(0.08))
                            .frame(width: 100, height: 100)
                        Image(systemName: "cpu")
                            .font(.system(size: 40))
                            .foregroundStyle(FHColors.aiPurple)
                    }
                    Text("需要配置 AI 模型")
                        .font(.title3.bold())
                    Text("请在设置中添加 API 配置\n支持 DeepSeek、智谱 GLM、Kimi 等模型")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Spacer()
                }
                .navigationTitle("AI 对话")
                .navigationBarTitleDisplayMode(.inline)
            } else {
                chatContent
            }
        }
    }

    private var chatContent: some View {
        ZStack(alignment: .bottom) {
            mainContent

            // @ mention popup — absolute positioned above input bar
            if showMentionPicker {
                mentionPickerView
                    .padding(.bottom, 60) // input bar height
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            // Model info banner
            if let config = defaultConfig {
                modelInfoBanner(config: config)
            }

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: FHSpacing.lg) {
                        if sortedMessages.isEmpty && !isStreaming {
                            welcomeView
                        }

                        ForEach(sortedMessages) { msg in
                            MessageBubble(message: msg)
                                .id(msg.id)
                        }

                        // Streaming message or thinking indicator
                        if isStreaming {
                            if streamedContent.isEmpty {
                                // Thinking indicator while waiting for first chunk
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("思考中...")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(FHSpacing.md)
                                .background(Color(.systemGray5))
                                .clipShape(RoundedRectangle(cornerRadius: FHRadius.large))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id("streaming")
                            } else {
                                StreamingBubble(content: streamedContent)
                                    .id("streaming")
                            }
                        }
                    }
                    .padding()
                }
                .onAppear { scrollProxy = proxy }
            }

            Divider()

            // Persistent medical disclaimer
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                Text("AI 内容仅供参考，不构成医疗建议。身体不适请及时就医。")
                    .font(.caption2)
            }
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.08))

            // Input bar
            inputBar
        }
        .navigationTitle(conversation?.title ?? "新对话")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadConversation() }
        .swAlert(isPresented: $showAlert, type: alertType, message: alertMessage)
    }

    // MARK: - Welcome

    private var welcomeView: some View {
        VStack(spacing: FHSpacing.lg) {
            Spacer().frame(height: 40)

            // Animated sparkle icon
            ZStack {
                Circle()
                    .fill(FHColors.aiPurple.opacity(0.08))
                    .frame(width: 100, height: 100)

                Image(systemName: "sparkles")
                    .font(.system(size: 44))
                    .foregroundStyle(FHColors.aiPurple)
                    .symbolRenderingMode(.hierarchical)
            }
            .fhGlowPulse(color: FHColors.aiPurple)

            Text("健康 AI 助手")
                .font(.title2.bold())

            Text("我可以帮你分析体检报告、解读指标、给出健康建议")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Medical disclaimer
            Label("AI 生成的内容可能有误，身体不适请及时就医", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: FHRadius.small))

            // Quick prompts
            VStack(spacing: FHSpacing.sm) {
                QuickPromptButton(icon: "doc.text.viewfinder", text: "帮我分析最近的体检报告") {
                    sendMessage("帮我分析最近的体检报告")
                }
                QuickPromptButton(icon: "exclamationmark.triangle", text: "我的健康数据有哪些异常？") {
                    sendMessage("我的健康数据有哪些异常？")
                }
                QuickPromptButton(icon: "heart.text.square", text: "给出一些健康改善建议") {
                    sendMessage("给出一些健康改善建议")
                }
            }
            .padding(.top, FHSpacing.sm)
        }
    }

    // MARK: - Model Info Banner

    private func modelInfoBanner(config: AIModelConfig) -> some View {
        HStack(spacing: FHSpacing.sm) {
            Image(systemName: config.provider.iconName)
                .font(.caption)
                .foregroundStyle(FHColors.aiPurple)

            Text(config.provider.displayName)
                .font(.caption.bold())

            Text(config.modelName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if config.isBuiltIn {
                Text("免费")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(FHColors.success.opacity(0.15))
                    .foregroundStyle(FHColors.success)
                    .clipShape(Capsule())
            }

            Spacer()
        }
        .padding(.horizontal, FHSpacing.lg)
        .padding(.vertical, FHSpacing.sm)
        .background(FHColors.subtleGray.opacity(0.5))
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: FHSpacing.md) {
            TextField("输入消息...", text: $inputText, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.plain)
                .padding(FHSpacing.md)
                .background(FHColors.subtleGray)
                .clipShape(RoundedRectangle(cornerRadius: FHRadius.xl))
                .onChange(of: inputText) { _, newValue in
                    withAnimation(.easeOut(duration: 0.15)) {
                        showMentionPicker = shouldShowMentionPicker(newValue)
                    }
                }

            Button {
                let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return }
                inputText = ""
                showMentionPicker = false
                sendMessage(text)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
                    .foregroundStyle(inputText.isEmpty || isStreaming ? .gray : FHColors.primary)
                    .scaleEffect(inputText.isEmpty ? 1.0 : 1.1)
                    .animation(FHAnimation.springBounce, value: inputText.isEmpty)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isStreaming)
        }
        .padding(.horizontal, FHSpacing.lg)
        .padding(.vertical, 10)
        .background(.background)
    }

    /// Floating list of family members for @ mention
    private var mentionPickerView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(familyUserNames, id: \.id) { member in
                Button {
                    insertMention(member.name)
                } label: {
                    HStack(spacing: FHSpacing.md) {
                        SWAvatar(name: member.name, size: 28, color: FHColors.primary)
                        Text(member.name)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, FHSpacing.lg)
                    .padding(.vertical, FHSpacing.md)
                }
                .buttonStyle(.plain)
                if member.id != familyUserNames.last?.id {
                    Divider().padding(.leading, 56)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: FHRadius.medium)
                .fill(FHColors.cardBackground)
                .shadow(color: .black.opacity(0.1), radius: 8, y: -2)
        )
        .padding(.horizontal, FHSpacing.lg)
    }

    /// All family members (excluding self) available for @ mention
    private var familyUserNames: [(id: UUID, name: String)] {
        guard let uid = appState.currentUserId, let uuid = UUID(uuidString: uid) else { return [] }
        let myGroups = allMembers.filter { $0.userId == uuid }.compactMap(\.group)
        let memberIds = Set(myGroups.flatMap(\.members).map(\.userId)).subtracting([uuid])
        return memberIds.compactMap { mid in
            guard let user = allUsers.first(where: { $0.id == mid }) else { return nil }
            return (id: user.id, name: user.name)
        }.sorted { $0.name < $1.name }
    }

    /// Check if @ was just typed (at end of text, or after a space)
    private func shouldShowMentionPicker(_ text: String) -> Bool {
        guard !familyUserNames.isEmpty else { return false }
        // Show if the last character is @ and it's either the first char or preceded by whitespace
        guard let last = text.last, last == "@" else { return false }
        if text.count == 1 { return true }
        let beforeAt = text[text.index(text.endIndex, offsetBy: -2)]
        return beforeAt.isWhitespace || beforeAt.isNewline
    }

    /// Insert the selected member name after the @ symbol
    private func insertMention(_ name: String) {
        // The last char should be @, append the name + space
        inputText += "\(name) "
        withAnimation(.easeOut(duration: 0.15)) {
            showMentionPicker = false
        }
    }

    // MARK: - Actions

    private func loadConversation() {
        guard let convId = conversationId else { return }
        let descriptor = FetchDescriptor<ChatConversation>()
        conversation = try? context.fetch(descriptor).first { $0.id == convId }
    }

    private func sendMessage(_ text: String) {
        guard let config = defaultConfig else {
            alertType = .error
            alertMessage = "请先在设置中配置 AI 模型"
            showAlert = true
            return
        }

        // Get API key from Keychain (works for both built-in and custom configs)
        guard let apiKey = KeychainManager.getAPIKey(for: config.id) else {
            alertType = .error
            alertMessage = "未找到 API Key，请在设置 → AI 模型设置中重新配置"
            showAlert = true
            return
        }

        guard let userId = appState.currentUserId, let uuid = UUID(uuidString: userId) else {
            alertType = .error
            alertMessage = "用户未登录，请重新登录"
            showAlert = true
            return
        }

        // Ensure conversation exists
        if conversation == nil {
            let targetUserId = forUserId ?? uuid
            let conv = ChatConversation(userId: targetUserId, title: String(text.prefix(20)), modelName: config.modelName)
            context.insert(conv)
            conversation = conv
        }

        // Add user message
        let userMsg = ChatMessage(role: .user, content: text)
        userMsg.conversation = conversation
        conversation?.messages.append(userMsg)
        conversation?.updatedAt = Date()
        try? context.save()

        scrollToBottom()

        // Stream AI response
        isStreaming = true
        streamedContent = ""

        Task {
            let service = LocalAIService(context: context)
            let currentMessages = sortedMessages

            // Parse @mentions from user text and resolve to UUIDs
            let targetUserIds = parseMentionedUserIds(from: text, conversationUserId: conversation?.userId)

            let stream = service.chat(messages: currentMessages, config: config, apiKey: apiKey, targetUserIds: targetUserIds)

            do {
                for try await chunk in stream {
                    streamedContent += chunk
                    scrollToBottom()
                }

                // Save assistant message if we got content
                if !streamedContent.isEmpty {
                    let assistantMsg = ChatMessage(role: .assistant, content: streamedContent)
                    assistantMsg.conversation = conversation
                    conversation?.messages.append(assistantMsg)
                    conversation?.updatedAt = Date()
                    try? context.save()
                } else {
                    alertType = .error
                    alertMessage = "AI 未返回内容，请检查模型配置\n\(config.apiEndpoint)"
                    showAlert = true
                }
            } catch {
                alertType = .error
                alertMessage = "AI 响应错误: \(error.localizedDescription)"
                showAlert = true
            }

            isStreaming = false
            streamedContent = ""
        }
    }

    private func scrollToBottom() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.2)) {
                if isStreaming {
                    scrollProxy?.scrollTo("streaming", anchor: .bottom)
                } else if let last = sortedMessages.last {
                    scrollProxy?.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - @ Mention Parsing

    /// Parse @name patterns from input text and resolve to user UUIDs.
    /// Falls back to the conversation's userId when no @ mentions are found.
    private func parseMentionedUserIds(from text: String, conversationUserId: UUID?) -> [UUID] {
        // Match @name patterns (Chinese/English/digits, 1-20 chars)
        let pattern = "@([\\p{L}\\p{N}]{1,20})"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return conversationUserId.map { [$0] } ?? []
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        var mentionedIds: [UUID] = []
        for match in matches {
            let nameRange = match.range(at: 1)
            let name = nsText.substring(with: nameRange)

            // Resolve name to userId
            if let user = allUsers.first(where: { $0.name == name }) {
                if !mentionedIds.contains(user.id) {
                    mentionedIds.append(user.id)
                }
            }
        }

        // If no valid @ mentions resolved, default to conversation owner
        if mentionedIds.isEmpty {
            if let uid = conversationUserId {
                return [uid]
            }
        }

        return mentionedIds
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: FHSpacing.xs) {
                Group {
                    if message.role == .assistant {
                        AutoSizingMarkdownView(markdown: message.content)
                    } else {
                        Text(message.content)
                            .font(.subheadline)
                    }
                }
                .padding(FHSpacing.md)
                .background(
                    message.role == .user
                        ? AnyShapeStyle(FHGradients.userBubble)
                        : AnyShapeStyle(Color(.systemGray5))
                )
                .foregroundStyle(message.role == .user ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: FHRadius.large))

                Text(message.createdAt, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if message.role == .assistant { Spacer(minLength: 60) }
        }
    }
}

struct StreamingBubble: View {
    let content: String
    @State private var showCursor = true

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack(alignment: .bottom, spacing: 0) {
                    AutoSizingMarkdownView(markdown: content)
                    if showCursor {
                        Text("▎")
                            .font(.subheadline)
                            .foregroundStyle(FHColors.primary)
                    }
                }
                .padding(FHSpacing.md)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: FHRadius.large))
            }
            Spacer(minLength: 60)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever()) { showCursor.toggle() }
        }
    }
}



struct QuickPromptButton: View {
    let icon: String
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: FHSpacing.md) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(FHColors.aiPurple)
                    .frame(width: 28, height: 28)
                    .background(FHColors.aiPurple.opacity(0.1))
                    .clipShape(Circle())

                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(FHSpacing.md)
            .background(FHColors.subtleGray)
            .clipShape(RoundedRectangle(cornerRadius: FHRadius.medium))
        }
        .fhPressStyle()
        .padding(.horizontal, FHSpacing.xxl)
    }
}
