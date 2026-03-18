import SwiftUI
import SwiftData

struct FamilyListView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(ServiceContainer.self) private var services
    @Query private var allMembers: [FamilyMember]
    @State private var showCreateGroup = false
    @State private var showAlert = false
    @State private var alertType: SWAlertType = .info
    @State private var alertMessage = ""

    private var currentUUID: UUID? {
        guard let id = appState.currentUserId else { return nil }
        return UUID(uuidString: id)
    }

    private var myGroups: [FamilyGroup] {
        guard let uuid = currentUUID else { return [] }
        return allMembers.filter { $0.userId == uuid }.compactMap(\.group)
    }

    var body: some View {
        NavigationStack {
            Group {
                if myGroups.isEmpty {
                    SWEmptyState(
                        icon: "person.3",
                        title: "创建家庭组",
                        description: "创建家庭组，管理全家人的健康数据",
                        actionTitle: "创建家庭组"
                    ) {
                        showCreateGroup = true
                    }
                } else {
                    groupList
                }
            }
            .navigationDestination(isPresented: $showCreateGroup) {
                CreateFamilyGroupView()
            }
            .navigationTitle("家庭")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { CreateFamilyGroupView() } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .swAlert(isPresented: $showAlert, type: alertType, message: alertMessage)
        }
    }

    private var groupList: some View {
        List {
            ForEach(myGroups) { group in
                NavigationLink {
                    FamilyGroupDetailView(group: group)
                } label: {
                    HStack(spacing: 12) {
                        SWAvatar(name: group.name, size: 48, color: FHColors.primary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(group.name).font(.headline)
                            Text("\(group.members.count) 位成员")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let uuid = currentUUID, group.creatorId == uuid {
                            SWBadge("管理员")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Create Family Group
struct CreateFamilyGroupView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(ServiceContainer.self) private var services
    @Environment(\.dismiss) private var dismiss
    @State private var groupName = ""
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("家庭组名称") {
                TextField("例如：温馨之家", text: $groupName)
            }
            if let error = errorMessage {
                Section { Text(error).foregroundStyle(.red).font(.caption) }
            }
        }
        .navigationTitle("创建家庭组")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("创建") {
                    Task { await createGroup() }
                }.disabled(groupName.isEmpty)
            }
        }
    }

    private func createGroup() async {
        guard let userId = appState.currentUserId, let uuid = UUID(uuidString: userId) else { return }
        do {
            _ = try await services.familyService.createGroup(name: groupName, creatorId: uuid)
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}

// MARK: - Family Group Detail
struct FamilyGroupDetailView: View {
    let group: FamilyGroup
    @EnvironmentObject private var appState: AppState
    @Environment(ServiceContainer.self) private var services
    @Environment(\.modelContext) private var context
    @Query private var allUsers: [User]
    @State private var showAddMember = false
    @State private var showDeleteConfirm = false
    @State private var showAlert = false
    @State private var alertType: SWAlertType = .info
    @State private var alertMessage = ""

    private var currentUUID: UUID? {
        guard let id = appState.currentUserId else { return nil }
        return UUID(uuidString: id)
    }

    private var isAdmin: Bool {
        guard let uuid = currentUUID else { return false }
        return group.creatorId == uuid
    }

    private func userName(for userId: UUID) -> String {
        allUsers.first(where: { $0.id == userId })?.name ?? "用户 \(userId.uuidString.prefix(6))"
    }

    var body: some View {
        List {
            // Members section
            Section("\(group.members.count) 位成员") {
                ForEach(group.members.sorted { $0.role == .admin && $1.role != .admin }) { member in
                    memberRow(member)
                        .contextMenu {
                            if isAdmin && member.userId != currentUUID {
                                Button {
                                    Task { await removeMember(member) }
                                } label: {
                                    Label("移除成员", systemImage: "person.badge.minus")
                                }
                                Button {
                                    Task { await transferAdmin(to: member) }
                                } label: {
                                    Label("转让管理员", systemImage: "person.badge.key")
                                }
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if isAdmin && member.userId != currentUUID {
                                Button(role: .destructive) {
                                    Task { await removeMember(member) }
                                } label: {
                                    Label("移除", systemImage: "person.badge.minus")
                                }
                            }
                        }
                }
            }

            // Admin: View members' reports
            if isAdmin {
                Section("查看成员报告") {
                    ForEach(group.members.filter { $0.userId != currentUUID }) { member in
                        NavigationLink {
                            MemberReportsView(memberId: member.userId)
                        } label: {
                            Label("查看 \(userName(for: member.userId)) 的报告", systemImage: "doc.text")
                        }
                    }
                }
            }

            // Add member
            if isAdmin {
                Section("添加成员") {
                    NavigationLink {
                        AddFamilyMemberView(group: group)
                    } label: {
                        Label("添加新成员", systemImage: "person.badge.plus")
                    }
                }
            }

            // Leave/delete
            Section {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Text(isAdmin ? "解散家庭组" : "退出家庭组")
                }
            }
        }
        .navigationTitle(group.name)
        .confirmationDialog("确认", isPresented: $showDeleteConfirm) {
            Button(isAdmin ? "解散家庭组" : "退出家庭组", role: .destructive) {
                Task { await leaveOrDelete() }
            }
        }
        .swAlert(isPresented: $showAlert, type: alertType, message: alertMessage)
    }

    private func memberRow(_ member: FamilyMember) -> some View {
        let name = userName(for: member.userId)
        let isMe = member.userId == currentUUID
        return HStack {
            SWAvatar(name: name, size: 40,
                     color: member.role == .admin ? FHColors.primary : FHColors.info)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(name)
                        .font(.subheadline)
                        .fontWeight(isMe ? .semibold : .regular)
                    if isMe {
                        Text("(我)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text("加入于 \(member.joinedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            Spacer()

            SWBadge(member.role.displayName,
                    color: member.role == .admin ? FHColors.primary : FHColors.info)
        }
    }

    private func removeMember(_ member: FamilyMember) async {
        do {
            try await services.familyService.removeMember(groupId: group.id, userId: member.userId)
            alertType = .success
            alertMessage = "已移除成员"
            showAlert = true
        } catch {
            alertType = .error
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    private func transferAdmin(to member: FamilyMember) async {
        // Change the new admin's role
        member.role = .admin
        // Find current admin and change to member
        if let currentAdmin = group.members.first(where: { $0.userId == currentUUID }) {
            currentAdmin.role = .member
        }
        // Update group creator
        group.creatorId = member.userId
        group.updatedAt = Date()
        try? context.save()

        alertType = .success
        alertMessage = "已转让管理员给 \(userName(for: member.userId))"
        showAlert = true
    }

    private func leaveOrDelete() async {
        guard let uuid = currentUUID else { return }
        do {
            if isAdmin {
                try await services.familyService.deleteGroup(id: group.id)
            } else {
                try await services.familyService.removeMember(groupId: group.id, userId: uuid)
            }
        } catch {
            alertType = .error
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }
}

// MARK: - Member Reports View (admin only)
struct MemberReportsView: View {
    let memberId: UUID
    @Query private var allReports: [HealthReport]

    private var memberReports: [HealthReport] {
        allReports.filter { $0.userId == memberId }
            .sorted { $0.reportDate > $1.reportDate }
    }

    var body: some View {
        Group {
            if memberReports.isEmpty {
                SWEmptyState(icon: "doc.text", title: "暂无报告", description: "该成员尚未上传体检报告")
            } else {
                List(memberReports) { report in
                    NavigationLink {
                        ReportDetailView(report: report)
                    } label: {
                        ReportRow(report: report)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("成员报告")
    }
}

// MARK: - Add Family Member
struct AddFamilyMemberView: View {
    let group: FamilyGroup
    @EnvironmentObject private var appState: AppState
    @Environment(ServiceContainer.self) private var services
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var gender: User.Gender = .male
    @State private var hasBirthDate = false
    @State private var birthDate = Date()
    @State private var errorMessage: String?
    @State private var isSaving = false

    private var currentUUID: UUID? {
        guard let id = appState.currentUserId else { return nil }
        return UUID(uuidString: id)
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

            Section {
                Toggle("设置出生日期", isOn: $hasBirthDate)
                if hasBirthDate {
                    DatePicker("出生日期", selection: $birthDate, displayedComponents: .date)
                }
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("添加成员")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("添加") {
                    Task { await addMember() }
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
            }
        }
    }

    private func addMember() async {
        guard let adminId = currentUUID else { return }
        isSaving = true
        errorMessage = nil

        do {
            // Create a local user for the new member
            let newUser = try await services.authService.createLocalUser(
                phone: "",
                name: name.trimmingCharacters(in: .whitespaces),
                gender: gender
            )
            // Set birth date if provided
            if hasBirthDate {
                newUser.birthDate = birthDate
                try await services.authService.updateUser(newUser)
            }
            // Add the new user to the family group
            try await services.familyService.addMember(
                groupId: group.id,
                userId: newUser.id,
                role: .member,
                invitedBy: adminId
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
