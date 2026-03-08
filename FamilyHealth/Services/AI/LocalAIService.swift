import Foundation
import SwiftData

/// Local AI service that uses user-configured OpenAI-compatible API
/// with RAG context from local health data.
@MainActor
final class LocalAIService: AIServiceProtocol {
    private let context: ModelContext
    private let client = OpenAIClient()

    init(context: ModelContext) {
        self.context = context
    }

    func chat(
        messages: [ChatMessage],
        config: AIModelConfig,
        apiKey: String
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // 1. Extract query from last user message
                    let query = messages.last(where: { $0.role == .user })?.content ?? ""

                    // 2. RAG: retrieve relevant health data context
                    let contextText = try await buildRAGContext(
                        query: query,
                        referenceIds: messages.last?.referenceIds ?? []
                    )

                    // 3. Build system prompt
                    let systemPrompt = """
                    你是 FamilyHealth 健康助手。你的任务是帮助用户理解他们的健康数据，\
                    包括体检报告和病例记录。基于以下健康数据进行分析和回答：

                    === 相关健康数据 ===
                    \(contextText)
                    === 数据结束 ===

                    注意事项：
                    1. 仅基于提供的数据进行分析，不要编造数据
                    2. 使用通俗易懂的语言，避免过于专业的术语
                    3. 如果数据不足以做出判断，请如实告知
                    4. 必要时建议用户咨询专业医生
                    5. 使用 Markdown 格式回复，包括列表、加粗等
                    """

                    // 4. Build message array for API
                    var apiMessages: [(role: String, content: String)] = [
                        ("system", systemPrompt)
                    ]
                    for msg in messages {
                        apiMessages.append((msg.role.rawValue, msg.content))
                    }

                    // 5. Stream response
                    let stream = client.chatStream(
                        endpoint: config.apiEndpoint,
                        apiKey: apiKey,
                        model: config.modelName,
                        messages: apiMessages
                    )

                    for try await chunk in await stream {
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func analyze(
        content: String,
        config: AIModelConfig,
        apiKey: String
    ) async throws -> String {
        let systemPrompt = """
        你是一个专业的健康报告分析助手。请仔细分析以下体检报告内容，给出：
        1. **关键指标概览** — 列出异常和正常的主要指标
        2. **健康风险提示** — 需要关注的问题
        3. **改善建议** — 饮食、运动、生活习惯建议
        4. **就医建议** — 是否需要进一步检查

        请使用 Markdown 格式，注意用通俗语言解释专业术语。
        """

        return try await client.chat(
            endpoint: config.apiEndpoint,
            apiKey: apiKey,
            model: config.modelName,
            messages: [
                ("system", systemPrompt),
                ("user", content),
            ]
        )
    }

    func testConnection(
        endpoint: String,
        apiKey: String,
        model: String
    ) async throws -> Bool {
        try await client.testConnection(endpoint: endpoint, apiKey: apiKey, model: model)
    }

    // MARK: - RAG Context Builder

    private func buildRAGContext(query: String, referenceIds: [UUID]) async throws -> String {
        var parts: [String] = []

        // 1. If specific references provided, fetch those directly
        if !referenceIds.isEmpty {
            for id in referenceIds {
                if let report = try fetchReport(id: id) {
                    parts.append(formatReport(report))
                }
                if let medCase = try fetchCase(id: id) {
                    parts.append(formatCase(medCase))
                }
            }
        }

        // 2. Simple keyword-based search as fallback (no vector DB in local mode)
        if parts.isEmpty && !query.isEmpty {
            let reports = try searchReports(query: query)
            let cases = try searchCases(query: query)
            parts += reports.prefix(3).map { formatReport($0) }
            parts += cases.prefix(3).map { formatCase($0) }
        }

        // 3. If still empty, include recent data overview
        if parts.isEmpty {
            let recentReports = try fetchRecentReports(limit: 5)
            let recentCases = try fetchRecentCases(limit: 5)
            if !recentReports.isEmpty {
                parts.append("### 最近体检报告")
                parts += recentReports.map { formatReport($0) }
            }
            if !recentCases.isEmpty {
                parts.append("### 最近病例记录")
                parts += recentCases.map { formatCase($0) }
            }
        }

        return parts.isEmpty ? "暂无相关健康数据" : parts.joined(separator: "\n\n")
    }

    // MARK: - Data Fetching Helpers

    private func fetchReport(id: UUID) throws -> HealthReport? {
        let predicate = #Predicate<HealthReport> { $0.id == id }
        return try context.fetch(FetchDescriptor(predicate: predicate)).first
    }

    private func fetchCase(id: UUID) throws -> MedicalCase? {
        let predicate = #Predicate<MedicalCase> { $0.id == id }
        return try context.fetch(FetchDescriptor(predicate: predicate)).first
    }

    private func searchReports(query: String) throws -> [HealthReport] {
        let predicate = #Predicate<HealthReport> {
            $0.title.localizedStandardContains(query) ||
            ($0.hospitalName?.localizedStandardContains(query) ?? false) ||
            ($0.notes?.localizedStandardContains(query) ?? false)
        }
        return try context.fetch(FetchDescriptor(predicate: predicate))
    }

    private func searchCases(query: String) throws -> [MedicalCase] {
        let predicate = #Predicate<MedicalCase> {
            $0.title.localizedStandardContains(query) ||
            ($0.diagnosis?.localizedStandardContains(query) ?? false)
        }
        return try context.fetch(FetchDescriptor(predicate: predicate))
    }

    private func fetchRecentReports(limit: Int) throws -> [HealthReport] {
        var descriptor = FetchDescriptor<HealthReport>(
            sortBy: [SortDescriptor(\.reportDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    private func fetchRecentCases(limit: Int) throws -> [MedicalCase] {
        var descriptor = FetchDescriptor<MedicalCase>(
            sortBy: [SortDescriptor(\.visitDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    // MARK: - Formatters

    private func formatReport(_ report: HealthReport) -> String {
        var s = "📋 **\(report.title)** (\(report.reportType.displayName))\n"
        s += "日期: \(report.reportDate.formatted(date: .abbreviated, time: .omitted))\n"
        if let h = report.hospitalName { s += "医院: \(h)\n" }
        if let n = report.notes { s += "备注: \(n)\n" }
        if let ai = report.aiAnalysis { s += "分析: \(ai)\n" }
        // Include OCR text from files
        for file in report.files {
            if let ocr = file.ocrText { s += "内容: \(ocr)\n" }
        }
        return s
    }

    private func formatCase(_ c: MedicalCase) -> String {
        var s = "🏥 **\(c.title)**\n"
        s += "就诊日期: \(c.visitDate.formatted(date: .abbreviated, time: .omitted))\n"
        if let h = c.hospitalName { s += "医院: \(h)\n" }
        if let d = c.doctorName { s += "医生: \(d)\n" }
        if let diag = c.diagnosis { s += "诊断: \(diag)\n" }
        if !c.symptoms.isEmpty { s += "症状: \(c.symptoms.joined(separator: "、"))\n" }
        for med in c.medications {
            s += "  💊 \(med.name)"
            if let dose = med.dosage { s += " \(dose)" }
            if let freq = med.frequency { s += " \(freq)" }
            s += "\n"
        }
        return s
    }
}
