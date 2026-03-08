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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    statsGrid
                    quickActions
                    recentSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .sheet(isPresented: $showUploadReport) { UploadReportView() }
            .sheet(isPresented: $showAddCase) { AddCaseView() }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.title.bold())
                Text(appState.mode.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.white.opacity(0.2))
                    .clipShape(Capsule())
            }
            Spacer()
            Circle()
                .fill(.white.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundStyle(.white)
                )
        }
        .padding()
        .background(.blue.gradient)
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
        LazyVGrid(columns: [.init(), .init()], spacing: 12) {
            StatCard(icon: "doc.text", title: "体检报告", value: "\(recentReports.count) 份", color: .blue)
            StatCard(icon: "list.clipboard", title: "病例记录", value: "\(recentCases.count) 份", color: .orange)
            StatCard(icon: "person.3", title: "家庭成员", value: memberCount, color: .green)
            StatCard(icon: "calendar", title: "上次体检", value: lastCheckupDate, color: .purple)
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
        VStack(alignment: .leading, spacing: 12) {
            SWSectionHeader("快捷操作")
            HStack(spacing: 16) {
                QuickActionButton(icon: "arrow.up.doc", title: "上传报告", color: .blue) {
                    showUploadReport = true
                }
                QuickActionButton(icon: "plus.circle", title: "录入病例", color: .green) {
                    showAddCase = true
                }
                QuickActionButton(icon: "brain.head.profile", title: "AI 对话", color: .purple) {}
                QuickActionButton(icon: "qrcode.viewfinder", title: "扫码加入", color: .orange) {}
            }
        }
    }

    // MARK: - Recent records
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SWSectionHeader("最近记录")

            if recentReports.isEmpty && recentCases.isEmpty {
                SWEmptyState(
                    icon: "tray",
                    title: "暂无记录",
                    description: "点击上方「上传报告」开始管理健康数据",
                    actionTitle: "上传报告"
                ) { showUploadReport = true }
            } else {
                ForEach(recentReports.prefix(3)) { report in
                    NavigationLink {
                        ReportDetailView(report: report)
                    } label: {
                        RecentRecordRow(
                            icon: "doc.text.fill", color: .blue,
                            title: report.title,
                            subtitle: report.hospitalName ?? "",
                            date: report.reportDate
                        )
                    }
                    .buttonStyle(.plain)
                }
                ForEach(recentCases.prefix(3)) { medCase in
                    NavigationLink {
                        CaseDetailView(medicalCase: medCase)
                    } label: {
                        RecentRecordRow(
                            icon: "list.clipboard.fill", color: .orange,
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
}

// MARK: - Subcomponents

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title3.bold())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 48, height: 48)
                    .background(color.opacity(0.12))
                    .clipShape(Circle())
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.primary)
            }
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.plain)
    }
}

struct RecentRecordRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let date: Date

    var body: some View {
        HStack(spacing: 12) {
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
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
