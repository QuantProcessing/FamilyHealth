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
