import SwiftUI
import SwiftData

struct RecordsView: View {
    @EnvironmentObject private var appState: AppState
    @Query private var allMembers: [FamilyMember]
    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var showUploadReport = false
    @State private var showAddCase = false
    @State private var fabScale: CGFloat = 1.0
    @State private var selectedMemberId: UUID?

    private var currentUUID: UUID? {
        guard let id = appState.currentUserId else { return nil }
        return UUID(uuidString: id)
    }

    private var hasFamily: Bool {
        guard let uuid = currentUUID else { return false }
        return allMembers.contains { $0.userId == uuid && $0.group != nil }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented control
                Picker("", selection: $selectedTab) {
                    Text("体检报告").tag(0)
                    Text("病例记录").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                // Search bar + family filter
                HStack(spacing: FHSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("搜索", text: $searchText)

                    if hasFamily, let memberId = Binding($selectedMemberId) {
                        Divider().frame(height: 20)
                        FamilyMemberPicker(selectedUserId: memberId)
                            .pickerStyle(.menu)
                    }
                }
                .padding(FHSpacing.md)
                .background(FHColors.subtleGray)
                .clipShape(RoundedRectangle(cornerRadius: FHRadius.medium))
                .padding(.horizontal)

                // Content
                if selectedTab == 0 {
                    ReportListContent(searchText: searchText, filterUserId: hasFamily ? selectedMemberId : nil)
                } else {
                    CaseListContent(searchText: searchText, filterUserId: hasFamily ? selectedMemberId : nil)
                }
            }
            .navigationTitle("健康档案")
            .overlay(alignment: .bottomTrailing) {
                // FAB button with shadow + animation
                Button {
                    if selectedTab == 0 {
                        showUploadReport = true
                    } else {
                        showAddCase = true
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(FHGradients.accentButton)
                        .clipShape(Circle())
                        .fhShadow(.heavy)
                        .scaleEffect(fabScale)
                }
                .fhPressStyle()
                .padding(.trailing, FHSpacing.xl)
                .padding(.bottom, FHSpacing.xl)
                .onAppear {
                    withAnimation(FHAnimation.gentlePulse) {
                        fabScale = 1.06
                    }
                }
            }
            .sheet(isPresented: $showUploadReport) {
                UploadReportView()
            }
            .sheet(isPresented: $showAddCase) {
                AddCaseView()
            }
            .onAppear {
                if selectedMemberId == nil, let uuid = currentUUID {
                    selectedMemberId = uuid
                }
            }
        }
    }
}

// MARK: - Report List
struct ReportListContent: View {
    let searchText: String
    var filterUserId: UUID? = nil
    @Query(sort: \HealthReport.reportDate, order: .reverse) private var reports: [HealthReport]

    private var filtered: [HealthReport] {
        var result = reports
        if let uid = filterUserId {
            result = result.filter { $0.userId == uid }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                ($0.hospitalName?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        return result
    }

    var body: some View {
        if filtered.isEmpty {
            SWEmptyState(
                icon: "doc.text",
                title: "暂无体检报告",
                description: "点击右下角 + 上传您的第一份报告"
            )
        } else {
            List(filtered) { report in
                NavigationLink {
                    ReportDetailView(report: report)
                } label: {
                    ReportRow(report: report)
                }
            }
            .listStyle(.plain)
        }
    }
}

struct ReportRow: View {
    let report: HealthReport

    var body: some View {
        HStack(spacing: FHSpacing.md) {
            // Thumbnail
            Group {
                if let firstFile = report.files.first,
                   let data = FileManager.default.contents(atPath: firstFile.localPath),
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(FHColors.reportBlue)
                        .font(.title3)
                }
            }
            .frame(width: 56, height: 56)
            .background(FHColors.subtleGray)
            .clipShape(RoundedRectangle(cornerRadius: FHRadius.small))

            VStack(alignment: .leading, spacing: FHSpacing.xs) {
                Text(report.title)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                if let hospital = report.hospitalName {
                    Text(hospital)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                SWBadge(report.reportType.displayName, color: FHColors.reportBlue)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: FHSpacing.xs) {
                Text(report.reportDate, format: .dateTime.year().month().day())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
            }
        }
        .padding(.vertical, FHSpacing.xs)
    }
}

// MARK: - Case List
struct CaseListContent: View {
    let searchText: String
    var filterUserId: UUID? = nil
    @Query(sort: \MedicalCase.visitDate, order: .reverse) private var cases: [MedicalCase]

    private var filtered: [MedicalCase] {
        var result = cases
        if let uid = filterUserId {
            result = result.filter { $0.userId == uid }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                ($0.diagnosis?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        return result
    }

    var body: some View {
        if filtered.isEmpty {
            SWEmptyState(
                icon: "list.clipboard",
                title: "暂无病例记录",
                description: "点击右下角 + 录入您的病例"
            )
        } else {
            List(filtered) { medCase in
                NavigationLink {
                    CaseDetailView(medicalCase: medCase)
                } label: {
                    CaseRow(medicalCase: medCase)
                }
            }
            .listStyle(.plain)
        }
    }
}

struct CaseRow: View {
    let medicalCase: MedicalCase

    var body: some View {
        HStack(spacing: FHSpacing.md) {
            SWAvatar(name: medicalCase.title, size: 44, color: FHColors.caseOrange)

            VStack(alignment: .leading, spacing: FHSpacing.xs) {
                Text(medicalCase.title)
                    .font(.subheadline.bold())
                if let diagnosis = medicalCase.diagnosis {
                    Text(diagnosis)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if !medicalCase.symptoms.isEmpty {
                    HStack(spacing: FHSpacing.xs) {
                        ForEach(medicalCase.symptoms.prefix(3), id: \.self) { s in
                            SWBadge(s, color: FHColors.caseOrange)
                        }
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: FHSpacing.xs) {
                Text(medicalCase.visitDate, format: .dateTime.year().month().day())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
            }
        }
        .padding(.vertical, FHSpacing.xs)
    }
}
