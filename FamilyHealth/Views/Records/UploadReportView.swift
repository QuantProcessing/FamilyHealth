import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Multi-step report upload flow
struct UploadReportView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(ServiceContainer.self) private var services
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var currentStep = 0
    @State private var imageData: [Data] = []
    @State private var title = ""
    @State private var hospitalName = ""
    @State private var reportDate = Date()
    @State private var reportType: HealthReport.ReportType = .annual
    @State private var notes = ""
    @State private var selectedMemberId: UUID?
    @State private var isSaving = false
    @State private var showAlert = false
    @State private var alertType: SWAlertType = .success
    @State private var alertMessage = ""
    @State private var showFileImporter = false
    @State private var pdfFileNames: [String] = []

    private let steps = ["选择文件", "填写信息", "确认保存"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SWStepper(steps: steps, currentStep: currentStep)
                    .padding(.vertical, FHSpacing.lg)

                TabView(selection: $currentStep) {
                    step1FileSelection.tag(0)
                    step2FillInfo.tag(1)
                    step3Confirm.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)

                // Bottom buttons
                bottomButtons
            }
            .navigationTitle("上传体检报告")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .swAlert(isPresented: $showAlert, type: alertType, message: alertMessage)
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    for url in urls {
                        guard url.startAccessingSecurityScopedResource() else { continue }
                        defer { url.stopAccessingSecurityScopedResource() }
                        if let data = try? Data(contentsOf: url) {
                            imageData.append(data)
                            pdfFileNames.append(url.lastPathComponent)
                        }
                    }
                case .failure(let error):
                    alertType = .error
                    alertMessage = "导入失败: \(error.localizedDescription)"
                    showAlert = true
                }
            }
            .onAppear {
                if selectedMemberId == nil,
                   let id = appState.currentUserId,
                   let uuid = UUID(uuidString: id) {
                    selectedMemberId = uuid
                }
            }
        }
    }

    private var step1FileSelection: some View {
        ScrollView {
            VStack(spacing: FHSpacing.xl) {
                // PDF file picker - primary action
                Button {
                    showFileImporter = true
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 40))
                            .foregroundStyle(FHColors.primary)
                        Text("点击选择报告文件")
                            .font(.headline)
                        Text("支持 PDF 格式的体检报告")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .background(
                        RoundedRectangle(cornerRadius: FHRadius.large)
                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                            .foregroundStyle(FHColors.primary.opacity(0.3))
                    )
                }
                .fhPressStyle()

                // Selected file preview
                if !imageData.isEmpty {
                    SWSectionHeader("已选 \(imageData.count) 个文件")
                    LazyVGrid(columns: [.init(), .init(), .init()], spacing: FHSpacing.sm) {
                        ForEach(imageData.indices, id: \.self) { index in
                            // PDF file placeholder
                            VStack(spacing: 4) {
                                Image(systemName: "doc.fill")
                                    .font(.title)
                                    .foregroundStyle(FHColors.primary)
                                Text(index < pdfFileNames.count ? pdfFileNames[index] : "PDF")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 100)
                            .background(FHColors.subtleGray)
                            .clipShape(RoundedRectangle(cornerRadius: FHRadius.small))
                            .overlay(alignment: .topTrailing) {
                                Button {
                                    imageData.remove(at: index)
                                    if index < pdfFileNames.count {
                                        pdfFileNames.remove(at: index)
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.white, .red)
                                }
                                .padding(4)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Step 2: Fill Info

    private var step2FillInfo: some View {
        Form {
            Section("报告标题") {
                if let memberId = Binding($selectedMemberId) {
                    FamilyMemberPicker(selectedUserId: memberId)
                }
                TextField("例：2025年度体检报告", text: $title)
            }

            Section("医院信息") {
                TextField("医院名称", text: $hospitalName)
                DatePicker("体检日期", selection: $reportDate, displayedComponents: .date)
            }

            Section("报告类型") {
                Picker("类型", selection: $reportType) {
                    ForEach(HealthReport.ReportType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("备注（可选）") {
                TextEditor(text: $notes)
                    .frame(minHeight: 80)
            }
        }
    }

    // MARK: - Step 3: Confirmation

    private var step3Confirm: some View {
        ScrollView {
            VStack(spacing: FHSpacing.lg) {
                SWCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(title.isEmpty ? "未填写标题" : title)
                                .font(.headline)
                            Spacer()
                            SWBadge(reportType.displayName)
                        }

                        if !hospitalName.isEmpty {
                            Label(hospitalName, systemImage: "building.2")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Label(reportDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if !notes.isEmpty {
                            Text(notes)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }

                        Divider()

                        Text("\(imageData.count) 个文件")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        // Thumbnail row
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: FHSpacing.sm) {
                                ForEach(imageData.indices, id: \.self) { index in
                                    if let uiImage = UIImage(data: imageData[index]) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 60, height: 60)
                                            .clipShape(RoundedRectangle(cornerRadius: FHRadius.small))
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        HStack(spacing: FHSpacing.lg) {
            if currentStep > 0 {
                Button {
                    withAnimation { currentStep -= 1 }
                } label: {
                    Text("上一步")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(FHColors.subtleGray)
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: FHRadius.medium))
                }
                .fhPressStyle()
            }

            Button {
                if currentStep < steps.count - 1 {
                    withAnimation { currentStep += 1 }
                } else {
                    Task { await saveReport() }
                }
            } label: {
                Group {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(currentStep < steps.count - 1 ? "下一步" : "保存")
                    }
                }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(nextEnabled ? FHGradients.accentButton : LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: FHRadius.medium))
                }
                .disabled(!nextEnabled || isSaving)
                .fhPressStyle()
        }
        .padding()
    }

    private var nextEnabled: Bool {
        switch currentStep {
        case 0: return !imageData.isEmpty
        case 1: return !title.isEmpty
        default: return true
        }
    }

    // MARK: - Actions

    private func saveReport() async {
        isSaving = true
        defer { isSaving = false }

        guard let uploaderId = appState.currentUserId, let uploaderUUID = UUID(uuidString: uploaderId) else { return }
        let targetUserId = selectedMemberId ?? uploaderUUID

        let report = HealthReport(
            userId: targetUserId,
            uploaderId: uploaderUUID,
            title: title,
            hospitalName: hospitalName.isEmpty ? nil : hospitalName,
            reportDate: reportDate,
            reportType: reportType,
            notes: notes.isEmpty ? nil : notes
        )

        // Save files and extract text
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let reportsDir = documentsURL.appendingPathComponent("reports/\(report.id.uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: reportsDir, withIntermediateDirectories: true)

        for (index, data) in imageData.enumerated() {
            // Detect file type
            let isPDF = data.count >= 5 && data.prefix(5).elementsEqual([0x25, 0x50, 0x44, 0x46, 0x2D])
            let fileType: ReportFile.FileType = isPDF ? .pdf : .image
            let fileName = isPDF ? "file_\(index).pdf" : "image_\(index).jpg"
            let filePath = reportsDir.appendingPathComponent(fileName)
            try? data.write(to: filePath)

            // Extract text from file
            let extractedText = await TextExtractor.extractText(from: data)

            let file = ReportFile(
                fileType: fileType,
                localPath: filePath.path,
                fileName: fileName,
                fileSize: Int64(data.count),
                ocrText: extractedText
            )
            file.report = report
            report.files.append(file)
        }

        do {
            try await services.reportService.createReport(report)
            alertType = .success
            alertMessage = "报告保存成功"
            showAlert = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
        } catch {
            alertType = .error
            alertMessage = "保存失败: \(error.localizedDescription)"
            showAlert = true
        }
    }
}
