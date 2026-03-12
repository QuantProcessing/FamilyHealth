import SwiftUI
import SwiftData
import PDFKit

/// Full report detail view with AI analysis display
struct ReportDetailView: View {
    let report: HealthReport
    @Environment(\.dismiss) private var dismiss
    @Environment(ServiceContainer.self) private var services
    @Environment(\.modelContext) private var context
    @Query private var aiConfigs: [AIModelConfig]
    @State private var showDeleteConfirm = false
    @State private var showEditReport = false
    @State private var showAlert = false
    @State private var alertType: SWAlertType = .info
    @State private var alertMessage = ""
    @State private var isAnalyzing = false

    private var defaultConfig: AIModelConfig? {
        aiConfigs.first(where: \.isDefault) ?? aiConfigs.first
    }

    var body: some View {
        ScrollView {
            VStack(spacing: FHSpacing.lg) {
                // Image preview
                filePreview
                    .fhStaggerEntrance(index: 0)

                // Report info card
                infoCard
                    .fhStaggerEntrance(index: 1)

                // AI analysis card
                aiAnalysisCard
                    .fhStaggerEntrance(index: 2)

                // Actions
                actionButtons
                    .fhStaggerEntrance(index: 3)
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
                Task { await deleteReport() }
            }
        } message: {
            Text("删除后无法恢复，确认要删除此报告吗？")
        }
        .sheet(isPresented: $showEditReport) {
            EditReportView(report: report)
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
                        VStack(spacing: FHSpacing.sm) {
                            Image(systemName: "doc.text")
                                .font(.title)
                                .foregroundStyle(.secondary)
                            Text("暂无文件")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, FHSpacing.xl)
                }
            } else {
                TabView {
                    ForEach(report.files) { file in
                        fileView(for: file)
                    }
                }
                .tabViewStyle(.page)
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: FHRadius.large))
                .overlay(alignment: .bottomTrailing) {
                    Text("\(report.files.count) 页")
                        .font(.caption2.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(FHSpacing.md)
                }
            }
        }
    }

    @ViewBuilder
    private func fileView(for file: ReportFile) -> some View {
        let data = FileManager.default.contents(atPath: file.localPath)
        let isPDF = file.fileType == .pdf || (data != nil && data!.count >= 5 && data!.prefix(5).elementsEqual([0x25, 0x50, 0x44, 0x46, 0x2D]))

        if isPDF, let data = data, let doc = PDFDocument(data: data) {
            PDFKitView(document: doc)
                .clipShape(RoundedRectangle(cornerRadius: FHRadius.medium))
        } else if let data = data, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: FHRadius.medium))
        } else {
            VStack(spacing: FHSpacing.sm) {
                Image(systemName: "doc.questionmark")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(file.fileName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(FHColors.subtleGray)
        }
    }

    // MARK: - Info Card

    private var infoCard: some View {
        SWCard {
            VStack(alignment: .leading, spacing: FHSpacing.md) {
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
            VStack(alignment: .leading, spacing: FHSpacing.md) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(FHColors.aiPurple)
                    Text("AI 智能分析")
                        .font(.headline)
                }

                if let analysis = report.aiAnalysis {
                    AutoSizingMarkdownView(markdown: analysis)
                } else {
                    VStack(spacing: FHSpacing.sm) {
                        if isAnalyzing {
                            ProgressView()
                                .controlSize(.large)
                                .padding()
                            Text("正在分析中...").font(.caption).foregroundStyle(.secondary)
                        } else {
                            Text("尚未进行 AI 分析")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button {
                                Task { await analyzeReport() }
                            } label: {
                                Label("开始分析", systemImage: "sparkles")
                                    .font(.subheadline.bold())
                                    .padding(.horizontal, FHSpacing.xl)
                                    .padding(.vertical, FHSpacing.md)
                                    .background(FHGradients.accentButton)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                            }
                            .fhPressStyle()
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
        HStack(spacing: FHSpacing.md) {
            Button {
                showEditReport = true
            } label: {
                Label("编辑", systemImage: "pencil")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FHSpacing.md)
                    .background(FHColors.subtleGray)
                    .clipShape(RoundedRectangle(cornerRadius: FHRadius.medium))
            }
            .buttonStyle(.plain)
            .fhPressStyle()

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("删除", systemImage: "trash")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FHSpacing.md)
                    .background(FHColors.danger.opacity(0.1))
                    .foregroundStyle(FHColors.danger)
                    .clipShape(RoundedRectangle(cornerRadius: FHRadius.medium))
            }
            .buttonStyle(.plain)
            .fhPressStyle()
        }
    }

    // MARK: - Actions

    private func deleteReport() async {
        do {
            try await services.reportService.deleteReport(id: report.id)
            dismiss()
        } catch {
            alertType = .error
            alertMessage = "删除失败: \(error.localizedDescription)"
            showAlert = true
        }
    }

    private func loadImage(from path: String) -> UIImage? {
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        return UIImage(data: data)
    }

    private func analyzeReport() async {
        guard let config = defaultConfig else {
            alertType = .error
            alertMessage = "请先在设置中配置 AI 模型"
            showAlert = true
            return
        }
        guard let apiKey = KeychainManager.getAPIKey(for: config.id) else {
            alertType = .error
            alertMessage = AIError.noAPIKey.localizedDescription
            showAlert = true
            return
        }

        isAnalyzing = true
        do {
            // Build report content text
            var content = "报告标题: \(report.title)\n"
            content += "类型: \(report.reportType.displayName)\n"
            content += "日期: \(report.reportDate.formatted(date: .abbreviated, time: .omitted))\n"
            if let hospital = report.hospitalName { content += "医院: \(hospital)\n" }
            if let notes = report.notes { content += "备注: \(notes)\n" }
            for file in report.files {
                if let ocr = file.ocrText { content += "\n内容:\n\(ocr)" }
            }

            let service = LocalAIService(context: context)
            let result = try await service.analyze(content: content, config: config, apiKey: apiKey)
            report.aiAnalysis = result
            try? context.save()

            alertType = .success
            alertMessage = "分析完成"
            showAlert = true
        } catch {
            alertType = .error
            alertMessage = "分析失败: \(error.localizedDescription)"
            showAlert = true
        }
        isAnalyzing = false
    }
}

// MARK: - Native PDF Viewer

/// UIViewRepresentable wrapping PDFKit's PDFView for native PDF rendering.
struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .clear
        pdfView.document = document
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        pdfView.document = document
    }
}
