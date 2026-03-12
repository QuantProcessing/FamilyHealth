import Foundation
import SwiftData

@Model
final class HealthReport {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var uploaderId: UUID
    var title: String
    var hospitalName: String?
    var reportDate: Date
    var reportType: ReportType
    var notes: String?
    var aiAnalysis: String?
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ReportFile.report)
    var files: [ReportFile] = []

    init(
        id: UUID = UUID(),
        userId: UUID,
        uploaderId: UUID,
        title: String,
        hospitalName: String? = nil,
        reportDate: Date,
        reportType: ReportType = .other,
        notes: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.uploaderId = uploaderId
        self.title = title
        self.hospitalName = hospitalName
        self.reportDate = reportDate
        self.reportType = reportType
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    enum ReportType: String, Codable, CaseIterable {
        case annual
        case specialist
        case followUp
        case other

        var displayName: String {
            switch self {
            case .annual: return String(localized: "年度体检")
            case .specialist: return String(localized: "专科检查")
            case .followUp: return String(localized: "复查")
            case .other: return String(localized: "其他")
            }
        }
    }
}

@Model
final class ReportFile {
    @Attribute(.unique) var id: UUID
    var fileType: FileType
    var localPath: String
    var remoteURL: String?
    var fileName: String
    var fileSize: Int64
    var ocrText: String?
    var report: HealthReport?

    init(
        id: UUID = UUID(),
        fileType: FileType,
        localPath: String,
        fileName: String,
        fileSize: Int64,
        remoteURL: String? = nil,
        ocrText: String? = nil
    ) {
        self.id = id
        self.fileType = fileType
        self.localPath = localPath
        self.fileName = fileName
        self.fileSize = fileSize
        self.remoteURL = remoteURL
        self.ocrText = ocrText
    }

    enum FileType: String, Codable {
        case image
        case pdf
    }
}

// MARK: - Codable DTOs for Remote API

/// DTO for serializing HealthReport to/from JSON (remote mode).
struct HealthReportDTO: Codable {
    let id: UUID
    let userId: UUID
    let uploaderId: UUID
    let title: String
    let hospitalName: String?
    let reportDate: Date
    let reportType: String
    let notes: String?
    let aiAnalysis: String?
    let createdAt: Date
    let updatedAt: Date
    let files: [ReportFileDTO]?

    enum CodingKeys: String, CodingKey {
        case id, title, notes, files
        case userId = "user_id"
        case uploaderId = "uploader_id"
        case hospitalName = "hospital_name"
        case reportDate = "report_date"
        case reportType = "report_type"
        case aiAnalysis = "ai_analysis"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// DTO for serializing ReportFile to/from JSON.
struct ReportFileDTO: Codable {
    let id: UUID
    let fileType: String
    let localPath: String
    let remoteURL: String?
    let fileName: String
    let fileSize: Int64
    let ocrText: String?

    enum CodingKeys: String, CodingKey {
        case id
        case fileType = "file_type"
        case localPath = "local_path"
        case remoteURL = "remote_url"
        case fileName = "file_name"
        case fileSize = "file_size"
        case ocrText = "ocr_text"
    }
}

extension HealthReport {
    /// Convert to DTO for remote API transmission.
    func toDTO() -> HealthReportDTO {
        HealthReportDTO(
            id: id, userId: userId, uploaderId: uploaderId,
            title: title, hospitalName: hospitalName,
            reportDate: reportDate, reportType: reportType.rawValue,
            notes: notes, aiAnalysis: aiAnalysis,
            createdAt: createdAt, updatedAt: updatedAt,
            files: files.map { $0.toDTO() }
        )
    }
}

extension ReportFile {
    /// Convert to DTO for remote API transmission.
    func toDTO() -> ReportFileDTO {
        ReportFileDTO(
            id: id, fileType: fileType.rawValue,
            localPath: localPath, remoteURL: remoteURL,
            fileName: fileName, fileSize: fileSize,
            ocrText: ocrText
        )
    }
}
