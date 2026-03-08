import SwiftUI
import SwiftData

struct RecordsView: View {
    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var showUploadReport = false
    @State private var showAddCase = false

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

                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("搜索", text: $searchText)
                }
                .padding(10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)

                // Content
                if selectedTab == 0 {
                    ReportListContent(searchText: searchText)
                } else {
                    CaseListContent(searchText: searchText)
                }
            }
            .navigationTitle("健康档案")
            .overlay(alignment: .bottomTrailing) {
                // FAB button
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
                        .background(.blue)
                        .clipShape(Circle())
                        .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
            .sheet(isPresented: $showUploadReport) {
                UploadReportView()
            }
            .sheet(isPresented: $showAddCase) {
                AddCaseView()
            }
        }
    }
}

// MARK: - Report List
struct ReportListContent: View {
    let searchText: String
    @Query(sort: \HealthReport.reportDate, order: .reverse) private var reports: [HealthReport]

    private var filtered: [HealthReport] {
        if searchText.isEmpty { return reports }
        return reports.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            ($0.hospitalName?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
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
        HStack(spacing: 12) {
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
                        .foregroundStyle(.blue)
                        .font(.title3)
                }
            }
            .frame(width: 56, height: 56)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(report.title)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                if let hospital = report.hospitalName {
                    Text(hospital)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                SWBadge(report.reportType.displayName)
            }

            Spacer()

            Text(report.reportDate, format: .dateTime.year().month().day())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Case List
struct CaseListContent: View {
    let searchText: String
    @Query(sort: \MedicalCase.visitDate, order: .reverse) private var cases: [MedicalCase]

    private var filtered: [MedicalCase] {
        if searchText.isEmpty { return cases }
        return cases.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            ($0.diagnosis?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
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
        HStack(spacing: 12) {
            SWAvatar(name: medicalCase.title, size: 44, color: .orange)

            VStack(alignment: .leading, spacing: 4) {
                Text(medicalCase.title)
                    .font(.subheadline.bold())
                if let diagnosis = medicalCase.diagnosis {
                    Text(diagnosis)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if !medicalCase.symptoms.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(medicalCase.symptoms.prefix(3), id: \.self) { s in
                            SWBadge(s, color: .orange)
                        }
                    }
                }
            }

            Spacer()

            Text(medicalCase.visitDate, format: .dateTime.year().month().day())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
