import Foundation
import SwiftData

@Model
final class HealthKitRecord: @unchecked Sendable {
    var id: UUID
    var date: Date
    var category: String    // "steps" / "heartRate" / "bloodOxygen" / "bloodPressure" / "weight" / "sleep" / "activeEnergy"
    var value: Double
    var unit: String        // "步" / "bpm" / "%" / "mmHg" / "kg" / "小时" / "kcal"
    var summary: String     // 文字摘要，用于 RAG 上下文

    init(
        id: UUID = UUID(),
        date: Date,
        category: String,
        value: Double,
        unit: String,
        summary: String
    ) {
        self.id = id
        self.date = date
        self.category = category
        self.value = value
        self.unit = unit
        self.summary = summary
    }

    /// Display name for category
    var categoryDisplayName: String {
        switch category {
        case "steps": return "步数"
        case "heartRate": return "心率"
        case "bloodOxygen": return "血氧"
        case "bloodPressureSystolic": return "收缩压"
        case "bloodPressureDiastolic": return "舒张压"
        case "weight": return "体重"
        case "sleep": return "睡眠"
        case "activeEnergy": return "活动能量"
        default: return category
        }
    }

    var categoryIcon: String {
        switch category {
        case "steps": return "figure.walk"
        case "heartRate": return "heart.fill"
        case "bloodOxygen": return "lungs.fill"
        case "bloodPressureSystolic", "bloodPressureDiastolic": return "waveform.path.ecg"
        case "weight": return "scalemass"
        case "sleep": return "bed.double.fill"
        case "activeEnergy": return "flame.fill"
        default: return "heart.text.square"
        }
    }
}
