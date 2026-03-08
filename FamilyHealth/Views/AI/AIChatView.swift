import SwiftUI
import SwiftData

/// AI Chat conversation view with streaming messages
struct AIChatView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var appState: AppState
    @Query private var aiConfigs: [AIModelConfig]

    let conversationId: UUID?
    @State private var conversation: ChatConversation?
    @State private var inputText = ""
    @State private var isStreaming = false
    @State private var streamedContent = ""
    @State private var showAlert = false
    @State private var alertType: SWAlertType = .error
    @State private var alertMessage = ""
    @State private var scrollProxy: ScrollViewProxy?

    private var defaultConfig: AIModelConfig? {
        aiConfigs.first(where: \.isDefault) ?? aiConfigs.first
    }

    private var sortedMessages: [ChatMessage] {
        (conversation?.messages ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if sortedMessages.isEmpty && !isStreaming {
                            welcomeView
                        }

                        ForEach(sortedMessages) { msg in
                            MessageBubble(message: msg)
                                .id(msg.id)
                        }

                        // Streaming message
                        if isStreaming && !streamedContent.isEmpty {
                            StreamingBubble(content: streamedContent)
                                .id("streaming")
                        }
                    }
                    .padding()
                }
                .onAppear { scrollProxy = proxy }
            }

            Divider()

            // Input bar
            inputBar
        }
        .navigationTitle(conversation?.title ?? "新对话")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let config = defaultConfig {
                    Text(config.modelName)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
            }
        }
        .onAppear { loadConversation() }
        .swAlert(isPresented: $showAlert, type: alertType, message: alertMessage)
    }

    // MARK: - Welcome

    private var welcomeView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
                .padding(.top, 60)

            Text("健康 AI 助手")
                .font(.title2.bold())

            Text("我可以帮你分析体检报告、解读指标、给出健康建议")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Quick prompts
            VStack(spacing: 8) {
                QuickPromptButton("帮我分析最近的体检报告") { sendMessage("帮我分析最近的体检报告") }
                QuickPromptButton("我的健康数据有哪些异常？") { sendMessage("我的健康数据有哪些异常？") }
                QuickPromptButton("给出一些健康改善建议") { sendMessage("给出一些健康改善建议") }
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("输入消息...", text: $inputText, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 20))

            Button {
                let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return }
                inputText = ""
                sendMessage(text)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
                    .foregroundStyle(inputText.isEmpty || isStreaming ? .gray : .blue)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isStreaming)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.background)
    }

    // MARK: - Actions

    private func loadConversation() {
        guard let convId = conversationId else { return }
        let predicate = #Predicate<ChatConversation> { $0.id == convId }
        conversation = try? context.fetch(FetchDescriptor(predicate: predicate)).first
    }

    private func sendMessage(_ text: String) {
        guard let config = defaultConfig else {
            alertType = .error
            alertMessage = "请先在设置中配置 AI 模型"
            showAlert = true
            return
        }

        guard let apiKey = KeychainManager.getAPIKey(for: config.id) else {
            alertType = .error
            alertMessage = AIError.noAPIKey.localizedDescription
            showAlert = true
            return
        }

        guard let userId = appState.currentUserId, let uuid = UUID(uuidString: userId) else { return }

        // Ensure conversation exists
        if conversation == nil {
            let conv = ChatConversation(userId: uuid, title: String(text.prefix(20)), modelName: config.modelName)
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
            let messages = sortedMessages

            let stream = service.chat(messages: messages, config: config, apiKey: apiKey)

            do {
                for try await chunk in stream {
                    streamedContent += chunk
                    scrollToBottom()
                }

                // Save assistant message
                let assistantMsg = ChatMessage(role: .assistant, content: streamedContent)
                assistantMsg.conversation = conversation
                conversation?.messages.append(assistantMsg)
                conversation?.updatedAt = Date()
                try? context.save()
            } catch {
                alertType = .error
                alertMessage = error.localizedDescription
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
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.subheadline)
                    .padding(12)
                    .background(message.role == .user ? .blue : Color(.systemGray5))
                    .foregroundStyle(message.role == .user ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

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
                    Text(content)
                        .font(.subheadline)
                    if showCursor {
                        Text("▎")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                }
                .padding(12)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            Spacer(minLength: 60)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever()) { showCursor.toggle() }
        }
    }
}

struct QuickPromptButton: View {
    let text: String
    let action: () -> Void

    init(_ text: String, action: @escaping () -> Void) {
        self.text = text
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack {
                Text(text)
                    .font(.subheadline)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.caption)
            }
            .padding(12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
    }
}
