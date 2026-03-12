import Foundation
import SwiftData

@Model
final class MedicalCase {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var uploaderId: UUID
    var title: String
    var hospitalName: String?
    var doctorName: String?
    var visitDate: Date
    var diagnosis: String?
    var symptoms: [String]
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Medication.medicalCase)
    var medications: [Medication] = []

    @Relationship(deleteRule: .cascade, inverse: \CaseAttachment.medicalCase)
    var attachments: [CaseAttachment] = []

    init(
        id: UUID = UUID(),
        userId: UUID,
        uploaderId: UUID,
        title: String,
        hospitalName: String? = nil,
        doctorName: String? = nil,
        visitDate: Date,
        diagnosis: String? = nil,
        symptoms: [String] = [],
        notes: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.uploaderId = uploaderId
        self.title = title
        self.hospitalName = hospitalName
        self.doctorName = doctorName
        self.visitDate = visitDate
        self.diagnosis = diagnosis
        self.symptoms = symptoms
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@Model
final class Medication {
    @Attribute(.unique) var id: UUID
    var name: String
    var dosage: String?
    var frequency: String?
    var startDate: Date?
    var endDate: Date?
    var medicalCase: MedicalCase?

    init(
        id: UUID = UUID(),
        name: String,
        dosage: String? = nil,
        frequency: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.dosage = dosage
        self.frequency = frequency
        self.startDate = startDate
        self.endDate = endDate
    }
}

@Model
final class CaseAttachment {
    @Attribute(.unique) var id: UUID
    var fileType: String
    var localPath: String
    var remoteURL: String?
    var fileName: String
    var medicalCase: MedicalCase?

    init(
        id: UUID = UUID(),
        fileType: String = "image",
        localPath: String,
        fileName: String,
        remoteURL: String? = nil
    ) {
        self.id = id
        self.fileType = fileType
        self.localPath = localPath
        self.fileName = fileName
        self.remoteURL = remoteURL
    }
}

// MARK: - Codable DTOs for Remote API

/// DTO for serializing MedicalCase to/from JSON (remote mode).
struct MedicalCaseDTO: Codable {
    let id: UUID
    let userId: UUID
    let uploaderId: UUID
    let title: String
    let hospitalName: String?
    let doctorName: String?
    let visitDate: Date
    let diagnosis: String?
    let symptoms: [String]
    let notes: String?
    let createdAt: Date
    let updatedAt: Date
    let medications: [MedicationDTO]?

    enum CodingKeys: String, CodingKey {
        case id, title, diagnosis, symptoms, notes, medications
        case userId = "user_id"
        case uploaderId = "uploader_id"
        case hospitalName = "hospital_name"
        case doctorName = "doctor_name"
        case visitDate = "visit_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// DTO for serializing Medication to/from JSON.
struct MedicationDTO: Codable {
    let id: UUID
    let name: String
    let dosage: String?
    let frequency: String?
    let startDate: Date?
    let endDate: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, dosage, frequency
        case startDate = "start_date"
        case endDate = "end_date"
    }
}

extension MedicalCase {
    /// Convert to DTO for remote API transmission.
    func toDTO() -> MedicalCaseDTO {
        MedicalCaseDTO(
            id: id, userId: userId, uploaderId: uploaderId,
            title: title, hospitalName: hospitalName,
            doctorName: doctorName, visitDate: visitDate,
            diagnosis: diagnosis, symptoms: symptoms,
            notes: notes, createdAt: createdAt, updatedAt: updatedAt,
            medications: medications.map { $0.toDTO() }
        )
    }
}

extension Medication {
    /// Convert to DTO for remote API transmission.
    func toDTO() -> MedicationDTO {
        MedicationDTO(
            id: id, name: name,
            dosage: dosage, frequency: frequency,
            startDate: startDate, endDate: endDate
        )
    }
}
