import SwiftUI
import SwiftData

/// Family member picker using a standard Picker control.
/// Scales to any number of members. Hidden when user has no family groups.
struct FamilyMemberPicker: View {
    @Binding var selectedUserId: UUID
    @EnvironmentObject private var appState: AppState
    @Query private var allUsers: [User]
    @Query private var allMembers: [FamilyMember]

    private var currentUUID: UUID? {
        guard let id = appState.currentUserId else { return nil }
        return UUID(uuidString: id)
    }

    /// All unique user IDs from groups the current user belongs to (including self).
    private var familyUserIds: [UUID] {
        guard let uuid = currentUUID else { return [] }
        let myGroups = allMembers.filter { $0.userId == uuid }.compactMap(\.group)
        let memberIds = Set(myGroups.flatMap(\.members).map(\.userId))
        var ids = Array(memberIds)
        ids.sort { a, b in
            if a == uuid { return true }
            if b == uuid { return false }
            let nameA = allUsers.first(where: { $0.id == a })?.name ?? ""
            let nameB = allUsers.first(where: { $0.id == b })?.name ?? ""
            return nameA < nameB
        }
        return ids
    }

    /// Whether to show the picker at all.
    var hasFamily: Bool {
        familyUserIds.count > 1
    }

    private func userName(for userId: UUID) -> String {
        if userId == currentUUID { return "我" }
        return allUsers.first(where: { $0.id == userId })?.name ?? "成员"
    }

    var body: some View {
        if hasFamily {
            Picker("为谁录入", selection: $selectedUserId) {
                ForEach(familyUserIds, id: \.self) { uid in
                    Text(userName(for: uid))
                        .tag(uid)
                }
            }
        }
    }
}
