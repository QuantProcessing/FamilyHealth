import SwiftUI
import SwiftData

struct AIChatListView: View {
    @EnvironmentObject private var appState: AppState
    @Query(sort: \ChatConversation.updatedAt, order: .reverse) private var conversations: [ChatConversation]
    @Query private var aiConfigs: [AIModelConfig]
    @Environment(\.modelContext) private var context

    private var hasAIConfig: Bool { !aiConfigs.isEmpty }

    var body: some View {
        NavigationStack {
            Group {
                if !hasAIConfig {
                    noConfigView
                } else if conversations.isEmpty {
                    emptyView
                } else {
                    conversationList
                }
            }
            .navigationTitle("AI 助手")
            .toolbar {
                if hasAIConfig {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            AIChatView(conversationId: nil)
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                    }
                }
            }
        }
    }

    private var noConfigView: some View {
        SWEmptyState(
            icon: "brain.head.profile",
            title: "配置 AI 模型",
            description: "使用 AI 功能前，请先在设置中配置 API 地址和 API Key",
            actionTitle: "前往设置"
        ) {}
    }

    private var emptyView: some View {
        NavigationLink {
            AIChatView(conversationId: nil)
        } label: {
            SWEmptyState(
                icon: "bubble.left.and.bubble.right",
                title: "开始对话",
                description: "与 AI 健康助手对话，获取专业的健康分析和建议",
                actionTitle: "新建对话"
            ) {}
        }
    }

    private var conversationList: some View {
        List {
            ForEach(conversations) { conv in
                NavigationLink {
                    AIChatView(conversationId: conv.id)
                } label: {
                    HStack(spacing: 12) {
                        SWAvatar(name: conv.title ?? "AI", size: 44, color: .purple)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(conv.title ?? "新对话")
                                    .font(.subheadline.bold())
                                Spacer()
                                Text(conv.updatedAt, format: .dateTime.month().day().hour().minute())
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if let model = conv.modelName {
                                SWBadge(model, color: .purple)
                            }
                            Text("\(conv.messages.count) 条消息")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    context.delete(conversations[index])
                }
                try? context.save()
            }
        }
        .listStyle(.plain)
    }
}
