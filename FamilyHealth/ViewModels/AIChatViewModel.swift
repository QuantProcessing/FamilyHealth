import SwiftUI
import SwiftData

/// ViewModel for AIChatView — manages message sending, streaming, and conversation lifecycle.
@Observable
final class AIChatViewModel {
    var conversation: ChatConversation?
    var inputText = ""
    var isStreaming = false
    var streamedContent = ""
    var showAlert = false
    var alertType: SWAlertType = .error
    var alertMessage = ""

    private var context: ModelContext?

    /// Sorted messages from the current conversation.
    var sortedMessages: [ChatMessage] {
        (conversation?.messages ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    /// Configure with a model context after view appears.
    func configure(context: ModelContext) {
        self.context = context
    }

    /// Load an existing conversation by ID.
    func loadConversation(id: UUID?) {
        guard let convId = id, let ctx = context else { return }
        let descriptor = FetchDescriptor<ChatConversation>()
        conversation = try? ctx.fetch(descriptor).first { $0.id == convId }
    }

    /// Send a message using the given AI configuration.
    func sendMessage(
        _ text: String,
        config: AIModelConfig,
        userId: UUID,
        scrollToBottom: @escaping () -> Void
    ) {
        guard let ctx = context else { return }

        guard let apiKey = KeychainManager.getAPIKey(for: config.id) else {
            alertType = .error
            alertMessage = AIError.noAPIKey.localizedDescription
            showAlert = true
            return
        }

        // Ensure conversation exists
        if conversation == nil {
            let conv = ChatConversation(userId: userId, title: String(text.prefix(20)), modelName: config.modelName)
            ctx.insert(conv)
            conversation = conv
        }

        // Add user message
        let userMsg = ChatMessage(role: .user, content: text)
        userMsg.conversation = conversation
        conversation?.messages.append(userMsg)
        conversation?.updatedAt = Date()
        try? ctx.save()

        scrollToBottom()

        // Stream AI response
        isStreaming = true
        streamedContent = ""

        Task { @MainActor in
            let service = LocalAIService(context: ctx)
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
                try? ctx.save()
            } catch {
                alertType = .error
                alertMessage = error.localizedDescription
                showAlert = true
            }

            isStreaming = false
            streamedContent = ""
        }
    }
}
