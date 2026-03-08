import SwiftUI

/// Full medical case recording form
struct AddCaseView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(ServiceContainer.self) private var services
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var hospitalName = ""
    @State private var doctorName = ""
    @State private var visitDate = Date()
    @State private var diagnosis = ""
    @State private var symptomInput = ""
    @State private var symptoms: [String] = []
    @State private var medications: [MedicationDraft] = []
    @State private var notes = ""
    @State private var isSaving = false
    @State private var showAlert = false
    @State private var alertType: SWAlertType = .success
    @State private var alertMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                // Basic info
                Section("基本信息") {
                    TextField("病例标题", text: $title)
                    DatePicker("就诊日期", selection: $visitDate, displayedComponents: .date)
                    TextField("医院名称", text: $hospitalName)
                    TextField("主治医生", text: $doctorName)
                }

                // Diagnosis
                Section("诊断结果") {
                    TextEditor(text: $diagnosis)
                        .frame(minHeight: 60)
                }

                // Symptoms
                Section("症状") {
                    ForEach(symptoms, id: \.self) { symptom in
                        HStack {
                            SWBadge(symptom, color: .orange)
                            Spacer()
                            Button {
                                symptoms.removeAll { $0 == symptom }
                            } label: {
                                Image(systemName: "xmark.circle")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    HStack {
                        TextField("添加症状", text: $symptomInput)
                            .onSubmit { addSymptom() }
                        Button("添加") { addSymptom() }
                            .disabled(symptomInput.isEmpty)
                    }
                }

                // Medications
                Section {
                    ForEach(medications.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(medications[index].name)
                                    .font(.subheadline.bold())
                                Spacer()
                                Button {
                                    medications.remove(at: index)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red)
                                        .font(.caption)
                                }
                            }
                            if let dosage = medications[index].dosage, !dosage.isEmpty {
                                Text("用量: \(dosage)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let freq = medications[index].frequency, !freq.isEmpty {
                                Text("频率: \(freq)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    NavigationLink {
                        AddMedicationForm { med in
                            medications.append(med)
                        }
                    } label: {
                        Label("添加用药记录", systemImage: "pills")
                    }
                } header: {
                    Text("用药记录")
                } footer: {
                    if medications.isEmpty {
                        Text("暂无用药记录")
                    }
                }

                // Notes
                Section("备注（可选）") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }
            }
            .navigationTitle("录入病例")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("保存")
                        }
                    }
                    .disabled(title.isEmpty || isSaving)
                }
            }
            .swAlert(isPresented: $showAlert, type: alertType, message: alertMessage)
        }
    }

    private func addSymptom() {
        let trimmed = symptomInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !symptoms.contains(trimmed) else { return }
        symptoms.append(trimmed)
        symptomInput = ""
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        guard let userId = appState.currentUserId, let uuid = UUID(uuidString: userId) else { return }

        let medicalCase = MedicalCase(
            userId: uuid,
            uploaderId: uuid,
            title: title,
            hospitalName: hospitalName.isEmpty ? nil : hospitalName,
            doctorName: doctorName.isEmpty ? nil : doctorName,
            visitDate: visitDate,
            diagnosis: diagnosis.isEmpty ? nil : diagnosis,
            symptoms: symptoms,
            notes: notes.isEmpty ? nil : notes
        )

        // Add medications
        for draft in medications {
            let med = Medication(
                name: draft.name,
                dosage: draft.dosage,
                frequency: draft.frequency,
                startDate: draft.startDate,
                endDate: draft.endDate
            )
            med.medicalCase = medicalCase
            medicalCase.medications.append(med)
        }

        do {
            try await services.caseService.createCase(medicalCase)
            alertType = .success
            alertMessage = "病例保存成功"
            showAlert = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
        } catch {
            alertType = .error
            alertMessage = "保存失败: \(error.localizedDescription)"
            showAlert = true
        }
    }
}

// MARK: - Medication Draft

struct MedicationDraft {
    var name: String = ""
    var dosage: String?
    var frequency: String?
    var startDate: Date?
    var endDate: Date?
}

// MARK: - Add Medication Form

struct AddMedicationForm: View {
    let onSave: (MedicationDraft) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var dosage = ""
    @State private var frequency = ""
    @State private var hasDateRange = false
    @State private var startDate = Date()
    @State private var endDate = Date()

    var body: some View {
        Form {
            Section("药品信息") {
                TextField("药品名称", text: $name)
                TextField("用量（如：每次 10mg）", text: $dosage)
                TextField("频率（如：每日 3 次）", text: $frequency)
            }

            Section {
                Toggle("设置用药时间", isOn: $hasDateRange)
                if hasDateRange {
                    DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                    DatePicker("结束日期", selection: $endDate, displayedComponents: .date)
                }
            }
        }
        .navigationTitle("添加用药")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    let draft = MedicationDraft(
                        name: name,
                        dosage: dosage.isEmpty ? nil : dosage,
                        frequency: frequency.isEmpty ? nil : frequency,
                        startDate: hasDateRange ? startDate : nil,
                        endDate: hasDateRange ? endDate : nil
                    )
                    onSave(draft)
                    dismiss()
                }
                .disabled(name.isEmpty)
            }
        }
    }
}
