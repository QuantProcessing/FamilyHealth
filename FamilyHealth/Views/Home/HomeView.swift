import SwiftUI
import SwiftData

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(ServiceContainer.self) private var services
    @Query(sort: \HealthReport.createdAt, order: .reverse) private var recentReports: [HealthReport]
    @Query(sort: \MedicalCase.createdAt, order: .reverse) private var recentCases: [MedicalCase]
    @Query private var familyMembers: [FamilyMember]
    @Query(sort: \HealthKitRecord.date, order: .reverse) private var healthRecords: [HealthKitRecord]
    @State private var showUploadReport = false
    @State private var showAddCase = false
    @State private var showAIChat = false
    @State private var showHealthData = false


    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FHSpacing.xl) {
                    headerSection
                        .fhStaggerEntrance(index: 0)
                    statsGrid
                    if !healthRecords.isEmpty {
                        healthDataCard
                            .fhStaggerEntrance(index: 2)
                    }
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

            .sheet(isPresented: $showAddCase) { AddCaseView() }
            .sheet(isPresented: $showHealthData) {
                NavigationStack {
                    HealthDataSheetView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("关闭") { showHealthData = false }
                            }
                        }
                }
            }
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

    // MARK: - Health Data Card
    private var healthDataCard: some View {
        VStack(alignment: .leading, spacing: FHSpacing.md) {
            HStack {
                SWSectionHeader("健康数据")
                Spacer()
                if let lastSync = HealthKitService.shared.lastSyncDate {
                    Text(lastSync.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            LazyVGrid(columns: [.init(), .init(), .init()], spacing: FHSpacing.sm) {
                ForEach(latestHealthMetrics, id: \.category) { metric in
                    VStack(spacing: 4) {
                        Image(systemName: metric.categoryIcon)
                            .font(.caption)
                            .foregroundStyle(healthColor(for: metric.category))
                        Text(metric.categoryDisplayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(formatHealthValue(metric))
                            .font(.subheadline.bold())
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FHSpacing.sm)
                    .background(FHColors.subtleGray)
                    .clipShape(RoundedRectangle(cornerRadius: FHRadius.medium))
                }
            }
        }
    }

    /// Get the latest record per category
    private var latestHealthMetrics: [HealthKitRecord] {
        var seen = Set<String>()
        var results: [HealthKitRecord] = []
        let order = ["steps", "heartRate", "sleep", "bloodOxygen", "weight", "activeEnergy"]
        // Group by category, take the most recent
        let byCategory = Dictionary(grouping: healthRecords) { $0.category }
        for cat in order {
            if let records = byCategory[cat], let latest = records.first {
                if seen.insert(cat).inserted {
                    results.append(latest)
                }
            }
        }
        return results
    }

    private func formatHealthValue(_ record: HealthKitRecord) -> String {
        let v = record.value
        switch record.category {
        case "steps", "activeEnergy":
            return "\(Int(v))\(record.unit)"
        case "sleep":
            return String(format: "%.1f\(record.unit)", v)
        case "bloodOxygen":
            return String(format: "%.0f%%", v)
        default:
            if v == v.rounded() {
                return "\(Int(v))\(record.unit)"
            }
            return String(format: "%.1f\(record.unit)", v)
        }
    }

    private func healthColor(for category: String) -> Color {
        switch category {
        case "steps": return .green
        case "heartRate": return .red
        case "sleep": return .indigo
        case "bloodOxygen": return .blue
        case "weight": return .orange
        case "activeEnergy": return .pink
        default: return FHColors.primary
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
                QuickActionButton(icon: "heart.text.square", title: "健康数据", color: .red) {
                    showHealthData = true
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

// MARK: - Health Data Sheet

struct HealthDataSheetView: View {
    @Query(sort: \HealthKitRecord.date, order: .reverse) private var records: [HealthKitRecord]
    @State private var isSyncing = false
    @State private var syncEnabled = HealthKitService.shared.isSyncEnabled

    private var groupedRecords: [(String, String, Color, [HealthKitRecord])] {
        let order: [(String, String, Color)] = [
            ("steps", "figure.walk", .green),
            ("heartRate", "heart.fill", .red),
            ("sleep", "bed.double.fill", .indigo),
            ("bloodOxygen", "lungs.fill", .blue),
            ("weight", "scalemass", .orange),
            ("activeEnergy", "flame.fill", .pink),
            ("bloodPressureSystolic", "waveform.path.ecg", .purple),
            ("bloodPressureDiastolic", "waveform.path.ecg", .purple),
        ]
        let byCategory = Dictionary(grouping: records) { $0.category }
        return order.compactMap { cat, icon, color in
            guard let items = byCategory[cat], !items.isEmpty else { return nil }
            return (items.first!.categoryDisplayName, icon, color, items)
        }
    }

    var body: some View {
        List {
            // Sync control
            Section {
                Toggle(isOn: $syncEnabled) {
                    Label("同步 Apple 健康数据", systemImage: "heart.text.square")
                }
                .onChange(of: syncEnabled) { _, newValue in
                    HealthKitService.shared.isSyncEnabled = newValue
                    if newValue { syncNow() }
                }

                Button {
                    syncNow()
                } label: {
                    HStack {
                        Label("立即同步", systemImage: "arrow.triangle.2.circlepath")
                        Spacer()
                        if isSyncing {
                            ProgressView().controlSize(.small)
                        }
                    }
                }
                .disabled(isSyncing || !syncEnabled)
            } footer: {
                if let date = HealthKitService.shared.lastSyncDate {
                    Text("上次同步: \(date.formatted(date: .abbreviated, time: .shortened))")
                }
            }

            // Data preview
            if records.isEmpty && syncEnabled {
                Section {
                    ContentUnavailableView(
                        "暂无数据",
                        systemImage: "heart.slash",
                        description: Text("点击「立即同步」获取健康数据")
                    )
                }
            }

            ForEach(groupedRecords, id: \.0) { name, icon, color, items in
                Section {
                    ForEach(items.prefix(7)) { record in
                        HStack {
                            Image(systemName: icon)
                                .font(.caption)
                                .foregroundStyle(color)
                                .frame(width: 24)
                            Text(record.date, format: .dateTime.month().day().weekday())
                                .font(.subheadline)
                            Spacer()
                            Text(formatValue(record))
                                .font(.subheadline.bold())
                                .foregroundStyle(color)
                        }
                    }
                } header: {
                    Text(name)
                }
            }
        }
        .navigationTitle("健康数据")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func syncNow() {
        isSyncing = true
        Task {
            do {
                try await HealthKitService.shared.requestAuthorization()
                try await HealthKitService.shared.syncRecentData()
            } catch {}
            isSyncing = false
        }
    }

    private func formatValue(_ record: HealthKitRecord) -> String {
        let v = record.value
        switch record.category {
        case "steps", "activeEnergy":
            return "\(Int(v)) \(record.unit)"
        case "sleep":
            return String(format: "%.1f \(record.unit)", v)
        case "bloodOxygen":
            return String(format: "%.0f%%", v)
        default:
            if v == v.rounded() { return "\(Int(v)) \(record.unit)" }
            return String(format: "%.1f \(record.unit)", v)
        }
    }
}
