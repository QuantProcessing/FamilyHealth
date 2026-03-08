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
