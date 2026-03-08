import SwiftUI
import SwiftData

/// Full report detail view with AI analysis display
struct ReportDetailView: View {
    let report: HealthReport
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    @State private var showAlert = false
    @State private var alertType: SWAlertType = .info
    @State private var alertMessage = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Image preview
                filePreview

                // Report info card
                infoCard

                // AI analysis card
                aiAnalysisCard

                // Actions
                actionButtons
            }
            .padding()
        }
        .navigationTitle("报告详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: report.title) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .confirmationDialog("确认删除", isPresented: $showDeleteConfirm) {
            Button("删除报告", role: .destructive) {
                // TODO: delete report
            }
        } message: {
            Text("删除后无法恢复，确认要删除此报告吗？")
        }
        .swAlert(isPresented: $showAlert, type: alertType, message: alertMessage)
    }

    // MARK: - File Preview

    private var filePreview: some View {
        Group {
            if report.files.isEmpty {
                SWCard {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "doc.text")
                                .font(.title)
                                .foregroundStyle(.secondary)
                            Text("暂无文件")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 20)
                }
            } else {
                TabView {
                    ForEach(report.files) { file in
                        if let uiImage = loadImage(from: file.localPath) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .tabViewStyle(.page)
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(alignment: .bottomTrailing) {
                    Text("\(report.files.count) 页")
                        .font(.caption2.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(12)
                }
            }
        }
    }

    // MARK: - Info Card

    private var infoCard: some View {
        SWCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SWBadge(report.reportType.displayName)
                    Spacer()
                    Text(report.reportDate, format: .dateTime.year().month().day())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let hospital = report.hospitalName {
                    Label(hospital, systemImage: "building.2")
                        .font(.subheadline)
                }

                if let notes = report.notes, !notes.isEmpty {
                    Divider()
                    Text(notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - AI Analysis

    private var aiAnalysisCard: some View {
        SWCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.blue)
                    Text("AI 智能分析")
                        .font(.headline)
                }

                if let analysis = report.aiAnalysis {
                    Text(analysis)
                        .font(.subheadline)
                } else {
                    VStack(spacing: 8) {
                        Text("尚未进行 AI 分析")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button {
                            alertType = .info
                            alertMessage = "AI 分析功能将在 M4 版本上线"
                            showAlert = true
                        } label: {
                            Label("开始分析", systemImage: "sparkles")
                                .font(.subheadline.bold())
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(.blue)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    // MARK: - Actions

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                alertType = .info
                alertMessage = "编辑功能开发中"
                showAlert = true
            } label: {
                Label("编辑", systemImage: "pencil")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("删除", systemImage: "trash")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.red.opacity(0.1))
                    .foregroundStyle(.red)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }

    private func loadImage(from path: String) -> UIImage? {
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        return UIImage(data: data)
    }
}
