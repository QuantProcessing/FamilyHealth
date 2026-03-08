import SwiftUI
import PhotosUI
import SwiftData

/// Multi-step report upload flow
struct UploadReportView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(ServiceContainer.self) private var services
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var currentStep = 0
    @State private var selectedPhotos: [PhotosPickerItem] = []
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

    private let steps = ["选择文件", "填写信息", "确认保存"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SWStepper(steps: steps, currentStep: currentStep)
                    .padding(.vertical, 16)

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
        }
    }

    // MARK: - Step 1: File Selection

    private var step1FileSelection: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Photo picker
                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: 10,
                    matching: .images
                ) {
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.up.doc")
                            .font(.system(size: 40))
                            .foregroundStyle(.blue)
                        Text("点击选择报告图片")
                            .font(.headline)
                        Text("支持从相册选择，最多 10 张")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                            .foregroundStyle(.blue.opacity(0.3))
                    )
                }
                .onChange(of: selectedPhotos) { _, newItems in
                    Task { await loadPhotos(newItems) }
                }

                // Selected image preview
                if !imageData.isEmpty {
                    SWSectionHeader("已选 \(imageData.count) 张")
                    LazyVGrid(columns: [.init(), .init(), .init()], spacing: 8) {
                        ForEach(imageData.indices, id: \.self) { index in
                            if let uiImage = UIImage(data: imageData[index]) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(alignment: .topTrailing) {
                                        Button {
                                            imageData.remove(at: index)
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
            }
            .padding()
        }
    }

    // MARK: - Step 2: Fill Info

    private var step2FillInfo: some View {
        Form {
            Section("报告标题") {
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
            VStack(spacing: 16) {
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
                            HStack(spacing: 8) {
                                ForEach(imageData.indices, id: \.self) { index in
                                    if let uiImage = UIImage(data: imageData[index]) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 60, height: 60)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
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
        HStack(spacing: 16) {
            if currentStep > 0 {
                Button {
                    withAnimation { currentStep -= 1 }
                } label: {
                    Text("上一步")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
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
                .background(nextEnabled ? .blue : .gray)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!nextEnabled || isSaving)
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

    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        var loaded: [Data] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                loaded.append(data)
            }
        }
        imageData = loaded
    }

    private func saveReport() async {
        isSaving = true
        defer { isSaving = false }

        guard let userId = appState.currentUserId, let uuid = UUID(uuidString: userId) else { return }

        let report = HealthReport(
            userId: uuid,
            uploaderId: uuid,
            title: title,
            hospitalName: hospitalName.isEmpty ? nil : hospitalName,
            reportDate: reportDate,
            reportType: reportType,
            notes: notes.isEmpty ? nil : notes
        )

        // Save images as report files
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let reportsDir = documentsURL.appendingPathComponent("reports/\(report.id.uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: reportsDir, withIntermediateDirectories: true)

        for (index, data) in imageData.enumerated() {
            let fileName = "image_\(index).jpg"
            let filePath = reportsDir.appendingPathComponent(fileName)
            try? data.write(to: filePath)

            let file = ReportFile(
                fileType: .image,
                localPath: filePath.path,
                fileName: fileName,
                fileSize: Int64(data.count)
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
