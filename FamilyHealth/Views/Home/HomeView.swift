import SwiftUI
import SwiftData

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(ServiceContainer.self) private var services
    @Query(sort: \HealthReport.createdAt, order: .reverse) private var recentReports: [HealthReport]
    @Query(sort: \MedicalCase.createdAt, order: .reverse) private var recentCases: [MedicalCase]
    @Query private var familyMembers: [FamilyMember]
    @State private var showUploadReport = false
    @State private var showAddCase = false
    @State private var showAIChat = false
    @State private var showScanner = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FHSpacing.xl) {
                    headerSection
                        .fhStaggerEntrance(index: 0)
                    statsGrid
                    quickActions
                        .fhStaggerEntrance(index: 3)
                    recentSection
                        .fhStaggerEntrance(index: 4)
                }
                .padding()
            }
            .background(FHColors.groupedBackground)
            .sheet(isPresented: $showUploadReport) { UploadReportView() }
            .sheet(isPresented: $showAIChat) {
                NavigationStack {
                    AIChatView(conversationId: nil)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("关闭") { showAIChat = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $showScanner) {
                QRScannerView { code in
                    showScanner = false
                    handleScannedCode(code)
                }
            }
            .sheet(isPresented: $showAddCase) { AddCaseView() }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: FHSpacing.xs) {
                Text(greeting)
                    .font(.title.bold())
            }
            Spacer()
            Circle()
                .fill(.white.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundStyle(.white)
                )
        }
        .padding()
        .background(FHGradients.primaryHero)
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: FHRadius.large))
        .fhShadow(.medium)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12: return String(localized: "早上好")
        case 12..<18: return String(localized: "下午好")
        default: return String(localized: "晚上好")
        }
    }

    // MARK: - Stats grid
    private var statsGrid: some View {
        LazyVGrid(columns: [.init(), .init()], spacing: FHSpacing.md) {
            StatCard(icon: "doc.text", title: "体检报告", value: "\(recentReports.count) 份", color: FHColors.reportBlue)
                .fhStaggerEntrance(index: 1)
            StatCard(icon: "list.clipboard", title: "病例记录", value: "\(recentCases.count) 份", color: FHColors.caseOrange)
                .fhStaggerEntrance(index: 1)
            StatCard(icon: "person.3", title: "家庭成员", value: memberCount, color: FHColors.familyGreen)
                .fhStaggerEntrance(index: 2)
            StatCard(icon: "calendar", title: "上次体检", value: lastCheckupDate, color: FHColors.calendarPurp)
                .fhStaggerEntrance(index: 2)
        }
    }

    private var memberCount: String {
        guard let userId = appState.currentUserId, let uuid = UUID(uuidString: userId) else { return "—" }
        let groups = familyMembers.filter { $0.userId == uuid }.compactMap(\.group)
        let total = Set(groups.flatMap(\.members).map(\.userId)).count
        return total > 0 ? "\(total) 人" : "—"
    }

    private var lastCheckupDate: String {
        guard let latest = recentReports.first?.reportDate else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: latest)
    }

    // MARK: - Quick actions
    private var quickActions: some View {
        VStack(alignment: .leading, spacing: FHSpacing.md) {
            SWSectionHeader("快捷操作")
            HStack(spacing: FHSpacing.lg) {
                QuickActionButton(icon: "arrow.up.doc", title: "上传报告", color: FHColors.reportBlue) {
                    showUploadReport = true
                }
                QuickActionButton(icon: "plus.circle", title: "录入病例", color: FHColors.familyGreen) {
                    showAddCase = true
                }
                QuickActionButton(icon: "brain.head.profile", title: "AI 对话", color: FHColors.aiPurple) {
                    showAIChat = true
                }
                QuickActionButton(icon: "qrcode.viewfinder", title: "扫码加入", color: FHColors.caseOrange) {
                    showScanner = true
                }
            }
        }
    }

    // MARK: - Recent records
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: FHSpacing.md) {
            SWSectionHeader("最近记录")

            if recentReports.isEmpty && recentCases.isEmpty {
                SWEmptyState(
                    icon: "tray",
                    title: "暂无记录",
                    description: "点击上方「上传报告」开始管理健康数据",
                    actionTitle: "上传报告"
                ) { showUploadReport = true }
                .frame(maxWidth: .infinity)
            } else {
                ForEach(Array(recentReports.prefix(3).enumerated()), id: \.element.id) { idx, report in
                    NavigationLink {
                        ReportDetailView(report: report)
                    } label: {
                        RecentRecordRow(
                            icon: "doc.text.fill", color: FHColors.reportBlue,
                            title: report.title,
                            subtitle: report.hospitalName ?? "",
                            date: report.reportDate
                        )
                    }
                    .buttonStyle(.plain)
                }
                ForEach(Array(recentCases.prefix(3).enumerated()), id: \.element.id) { idx, medCase in
                    NavigationLink {
                        CaseDetailView(medicalCase: medCase)
                    } label: {
                        RecentRecordRow(
                            icon: "list.clipboard.fill", color: FHColors.caseOrange,
                            title: medCase.title,
                            subtitle: medCase.diagnosis ?? "",
                            date: medCase.visitDate
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - QR Code Handling
    private func handleScannedCode(_ code: String) {
        guard let url = URL(string: code),
              url.scheme == "familyhealth",
              url.host == "invite",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let groupIdStr = components.queryItems?.first(where: { $0.name == "group" })?.value,
              let groupId = UUID(uuidString: groupIdStr),
              let userId = appState.currentUserId,
              let uuid = UUID(uuidString: userId) else {
            return
        }
        Task {
            do {
                try await services.familyService.addMember(
                    groupId: groupId, userId: uuid, role: .member, invitedBy: uuid)
            } catch {}
        }
    }
}

// MARK: - Subcomponents

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: FHSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: FHRadius.small)
                    .fill(color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title3.bold())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(FHColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: FHRadius.medium))
        .fhShadow(.light)
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: FHSpacing.sm) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 48, height: 48)
                    .background(color.opacity(0.10))
                    .clipShape(Circle())
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.primary)
            }
        }
        .frame(maxWidth: .infinity)
        .fhPressStyle()
    }
}

struct RecentRecordRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let date: Date

    var body: some View {
        HStack(spacing: FHSpacing.md) {
            // Left color bar accent
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 4, height: 40)

            Image(systemName: icon)
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                if !subtitle.isEmpty {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(date, format: .dateTime.year().month().day())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(FHColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: FHRadius.medium))
        .fhShadow(.light)
    }
}
