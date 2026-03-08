import SwiftUI
import SwiftData

struct FamilyListView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(ServiceContainer.self) private var services
    @Query private var allMembers: [FamilyMember]
    @State private var showScanner = false
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
                    ) {}
                } else {
                    groupList
                }
            }
            .navigationTitle("家庭")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showScanner = true } label: {
                        Image(systemName: "qrcode.viewfinder")
                    }
                    if myGroups.count < 2 {
                        NavigationLink { CreateFamilyGroupView() } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showScanner) {
                NavigationStack {
                    QRScannerView { code in
                        showScanner = false
                        handleScannedCode(code)
                    }
                    .navigationTitle("扫码加入")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("取消") { showScanner = false }
                        }
                    }
                    .ignoresSafeArea()
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
                        SWAvatar(name: group.name, size: 48, color: .blue)

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

            if myGroups.count < 2 {
                Section {
                    Text("最多可加入 2 个家庭组")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func handleScannedCode(_ code: String) {
        // Parse invite URL: familyhealth://invite?code=XXX&group=YYY
        guard code.hasPrefix("familyhealth://invite"),
              let uuid = currentUUID else {
            alertType = .error
            alertMessage = "无效的邀请码"
            showAlert = true
            return
        }

        Task {
            do {
                // In local mode, we just parse the group ID from the QR code
                if let groupIdStr = URLComponents(string: code)?
                    .queryItems?.first(where: { $0.name == "group" })?.value,
                   let groupId = UUID(uuidString: groupIdStr) {
                    try await services.familyService.addMember(
                        groupId: groupId, userId: uuid,
                        role: .member, invitedBy: uuid
                    )
                    alertType = .success
                    alertMessage = "成功加入家庭组"
                }
            } catch {
                alertType = .error
                alertMessage = error.localizedDescription
            }
            showAlert = true
        }
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
    @State private var showQRInvite = false
    @State private var showInviteByPhone = false
    @State private var showDeleteConfirm = false
    @State private var inviteCode = ""
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

    var body: some View {
        List {
            // Members section
            Section("\(group.members.count) 位成员") {
                ForEach(group.members) { member in
                    memberRow(member)
                }
            }

            // Admin: View members' reports
            if isAdmin {
                Section("查看成员报告") {
                    ForEach(group.members.filter { $0.userId != currentUUID }) { member in
                        NavigationLink {
                            MemberReportsView(memberId: member.userId)
                        } label: {
                            Label("查看 \(member.userId.uuidString.prefix(8)) 的报告", systemImage: "doc.text")
                        }
                    }
                }
            }

            // Invite actions
            if isAdmin {
                Section("邀请新成员") {
                    Button {
                        Task { await generateQR() }
                    } label: {
                        Label("生成邀请二维码", systemImage: "qrcode")
                    }
                    Button { showInviteByPhone = true } label: {
                        Label("通过手机号邀请", systemImage: "phone")
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
        .sheet(isPresented: $showQRInvite) {
            QRInviteView(groupName: group.name, inviteCode: inviteCode)
        }
        .alert("通过手机号邀请", isPresented: $showInviteByPhone) {
            TextField("手机号", text: .constant(""))
            Button("邀请") {}
            Button("取消", role: .cancel) {}
        }
        .confirmationDialog("确认", isPresented: $showDeleteConfirm) {
            Button(isAdmin ? "解散家庭组" : "退出家庭组", role: .destructive) {
                Task { await leaveOrDelete() }
            }
        }
        .swAlert(isPresented: $showAlert, type: alertType, message: alertMessage)
    }

    private func memberRow(_ member: FamilyMember) -> some View {
        HStack {
            SWAvatar(name: "U\(member.userId.uuidString.prefix(2))", size: 40,
                     color: member.role == .admin ? .blue : .gray)

            VStack(alignment: .leading, spacing: 2) {
                Text("用户 \(member.userId.uuidString.prefix(8))")
                    .font(.subheadline)
                Text("加入于 \(member.joinedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            Spacer()

            SWBadge(member.role.displayName,
                    color: member.role == .admin ? .blue : .gray)
        }
    }

    private func generateQR() async {
        do {
            inviteCode = try await services.familyService.generateInviteCode(groupId: group.id)
            showQRInvite = true
        } catch {
            alertType = .error
            alertMessage = error.localizedDescription
            showAlert = true
        }
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
