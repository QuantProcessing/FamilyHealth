import SwiftUI
import SwiftData

struct AIChatListView: View {
    @EnvironmentObject private var appState: AppState
    @Query(sort: \ChatConversation.updatedAt, order: .reverse) private var conversations: [ChatConversation]
    @Query private var aiConfigs: [AIModelConfig]
    @Query private var allMembers: [FamilyMember]
    @Environment(\.modelContext) private var context

    @State private var selectedMemberId: UUID?
    @State private var conversationToDelete: ChatConversation?
    @State private var conversationToRename: ChatConversation?
    @State private var renameText = ""
    @State private var showRenameAlert = false
    @State private var showDeleteConfirm = false

    private var hasAIConfig: Bool { !aiConfigs.isEmpty }

    private var currentUUID: UUID? {
        guard let id = appState.currentUserId else { return nil }
        return UUID(uuidString: id)
    }

    /// Whether user has any family groups
    private var hasFamily: Bool {
        guard let uuid = currentUUID else { return false }
        return allMembers.contains { $0.userId == uuid && $0.group != nil }
    }

    private var filteredConversations: [ChatConversation] {
        guard let filterUUID = selectedMemberId, hasFamily else { return conversations }
        return conversations.filter { $0.userId == filterUUID }
    }

    var body: some View {
        NavigationStack {
            Group {
                if !hasAIConfig {
                    noConfigView
                } else if filteredConversations.isEmpty {
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
                            AIChatView(conversationId: nil, forUserId: selectedMemberId)
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                    }
                }
            }
            .onAppear {
                if selectedMemberId == nil, let uuid = currentUUID {
                    selectedMemberId = uuid
                }
            }
            .alert("重命名对话", isPresented: $showRenameAlert) {
                TextField("对话标题", text: $renameText)
                Button("确定") {
                    if let conv = conversationToRename {
                        conv.title = renameText.trimmingCharacters(in: .whitespaces)
                        conv.updatedAt = Date()
                        try? context.save()
                    }
                }
                Button("取消", role: .cancel) {}
            }
            .confirmationDialog("确认删除", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("删除对话", role: .destructive) {
                    if let conv = conversationToDelete {
                        context.delete(conv)
                        try? context.save()
                    }
                }
            } message: {
                Text("删除后无法恢复，确定要删除这个对话吗？")
            }
        }
    }

    private var noConfigView: some View {
        VStack {
            SWEmptyState(
                icon: "brain.head.profile",
                title: "配置 AI 模型",
                description: "使用 AI 功能前，请先在设置中配置 API 地址和 API Key"
            )
            NavigationLink {
                AIModelSettingsView()
            } label: {
                Text("前往设置")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(FHGradients.accentButton)
                    .clipShape(RoundedRectangle(cornerRadius: FHRadius.medium))
            }
            .padding(.horizontal, FHSpacing.xxl)
        }
    }

    private var emptyView: some View {
        VStack {
            SWEmptyState(
                icon: "bubble.left.and.bubble.right",
                title: "开始对话",
                description: "与 AI 健康助手对话，获取专业的健康分析和建议"
            )
            NavigationLink {
                AIChatView(conversationId: nil, forUserId: selectedMemberId)
            } label: {
                Text("新建对话")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(FHGradients.accentButton)
                    .clipShape(RoundedRectangle(cornerRadius: FHRadius.medium))
            }
            .padding(.horizontal, FHSpacing.xxl)
        }
    }

    private var conversationList: some View {
        List {
            // Family member filter
            if hasFamily, let memberId = Binding($selectedMemberId) {
                FamilyMemberPicker(selectedUserId: memberId)
            }

            ForEach(filteredConversations) { conv in
                NavigationLink {
                    AIChatView(conversationId: conv.id)
                } label: {
                    HStack(spacing: 12) {
                        SWAvatar(name: conv.title ?? "AI", size: 44, color: FHColors.aiPurple)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(conv.title ?? "新对话")
                                    .font(.subheadline.bold())
                                Spacer()
                                Text(conv.updatedAt, format: .dateTime.month().day().hour().minute())
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if let lastMsg = conv.messages.sorted(by: { $0.createdAt < $1.createdAt }).last {
                                Text(lastMsg.content.prefix(50) + (lastMsg.content.count > 50 ? "..." : ""))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            } else {
                                Text("\(conv.messages.count) 条消息")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .contextMenu {
                    Button {
                        conversationToRename = conv
                        renameText = conv.title ?? ""
                        showRenameAlert = true
                    } label: {
                        Label("重命名", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        conversationToDelete = conv
                        showDeleteConfirm = true
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        conversationToDelete = conv
                        showDeleteConfirm = true
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}
