import SwiftUI

/// Medical case detail view
struct CaseDetailView: View {
    let medicalCase: MedicalCase
    @State private var showDeleteConfirm = false
    @State private var showAlert = false
    @State private var alertType: SWAlertType = .info
    @State private var alertMessage = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Diagnosis card
                SWCard {
                    VStack(alignment: .leading, spacing: 12) {
                        SWSectionHeader("诊断信息")

                        if let hospital = medicalCase.hospitalName {
                            Label(hospital, systemImage: "building.2")
                                .font(.subheadline)
                        }
                        if let doctor = medicalCase.doctorName {
                            Label(doctor, systemImage: "stethoscope")
                                .font(.subheadline)
                        }
                        Label(medicalCase.visitDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if let diagnosis = medicalCase.diagnosis {
                            Divider()
                            Text(diagnosis)
                                .font(.body)
                        }
                    }
                }

                // Symptoms
                if !medicalCase.symptoms.isEmpty {
                    SWCard {
                        VStack(alignment: .leading, spacing: 12) {
                            SWSectionHeader("症状")
                            FlowLayout(spacing: 8) {
                                ForEach(medicalCase.symptoms, id: \.self) { symptom in
                                    SWBadge(symptom, color: .orange)
                                }
                            }
                        }
                    }
                }

                // Medications
                if !medicalCase.medications.isEmpty {
                    SWCard {
                        VStack(alignment: .leading, spacing: 12) {
                            SWSectionHeader("用药记录")
                            ForEach(medicalCase.medications) { med in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(med.name)
                                            .font(.subheadline.bold())
                                        if let dosage = med.dosage {
                                            Text("用量: \(dosage)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        if let freq = med.frequency {
                                            Text("频率: \(freq)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "pills.fill")
                                        .foregroundStyle(.blue)
                                }
                                if med.id != medicalCase.medications.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }

                // Notes
                if let notes = medicalCase.notes, !notes.isEmpty {
                    SWCard {
                        VStack(alignment: .leading, spacing: 8) {
                            SWSectionHeader("备注")
                            Text(notes)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Actions
                HStack(spacing: 12) {
                    Button {
                        alertType = .info
                        alertMessage = "AI 分析功能将在 M4 版本上线"
                        showAlert = true
                    } label: {
                        Label("AI 分析", systemImage: "sparkles")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.blue)
                            .foregroundStyle(.white)
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
            .padding()
        }
        .navigationTitle(medicalCase.title)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("确认删除", isPresented: $showDeleteConfirm) {
            Button("删除病例", role: .destructive) {}
        }
        .swAlert(isPresented: $showAlert, type: alertType, message: alertMessage)
    }
}

/// Simple flow layout for symptom tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                                  proposal: .unspecified)
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let width = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var maxHeight: CGFloat = 0
        var rowMaxHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowMaxHeight + spacing
                rowMaxHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowMaxHeight = max(rowMaxHeight, size.height)
            maxHeight = max(maxHeight, y + size.height)
            x += size.width + spacing
        }

        return (CGSize(width: width, height: maxHeight), positions)
    }
}
