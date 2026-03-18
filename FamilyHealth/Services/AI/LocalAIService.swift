import Foundation
import SwiftData
import NaturalLanguage

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
        apiKey: String,
        targetUserIds: [UUID] = []
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // 1. Extract query from last user message
                    let query = messages.last(where: { $0.role == .user })?.content ?? ""

                    // 2. RAG: retrieve relevant health data context
                    let contextText = try await self.buildRAGContext(
                        query: query,
                        referenceIds: messages.last?.referenceIds ?? [],
                        targetUserIds: targetUserIds
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
                    let stream = await client.chatStream(
                        endpoint: config.apiEndpoint,
                        apiKey: apiKey,
                        model: config.modelName,
                        messages: apiMessages
                    )

                    for try await chunk in stream {
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

    private func buildRAGContext(query: String, referenceIds: [UUID], targetUserIds: [UUID]) async throws -> String {
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

        // 2. Semantic search using NLEmbedding (fallback to keyword search)
        if parts.isEmpty && !query.isEmpty {
            let (reports, cases) = try semanticSearch(query: query, topK: 3, targetUserIds: targetUserIds)
            parts += reports.map { formatReport($0) }
            parts += cases.map { formatCase($0) }
        }

        // 3. If still empty, include recent data overview
        if parts.isEmpty {
            let recentReports = try fetchRecentReports(limit: 5, targetUserIds: targetUserIds)
            let recentCases = try fetchRecentCases(limit: 5, targetUserIds: targetUserIds)
            if !recentReports.isEmpty {
                parts.append("### 最近体检报告")
                parts += recentReports.map { formatReport($0) }
            }
            if !recentCases.isEmpty {
                parts.append("### 最近病例记录")
                parts += recentCases.map { formatCase($0) }
            }
        }

        // 4. Always include recent HealthKit data if available
        let healthRecords = try fetchRecentHealthKitData()
        if !healthRecords.isEmpty {
            parts.append("### Apple 健康数据（最近7天）")
            parts += healthRecords.map { $0.summary }
        }

        return parts.isEmpty ? "暂无相关健康数据" : parts.joined(separator: "\n\n")
    }

    // MARK: - NLEmbedding Semantic Search

    /// Compute sentence-level cosine similarity using NLEmbedding.
    /// Falls back to keyword search if embedding is unavailable.
    private func semanticSearch(query: String, topK: Int, targetUserIds: [UUID]) throws -> ([HealthReport], [MedicalCase]) {
        // Try to get sentence embedding (supports Chinese + English)
        guard let embedding = NLEmbedding.sentenceEmbedding(for: .simplifiedChinese) else {
            // Fallback: keyword search
            return (try keywordSearchReports(query: query, limit: topK, targetUserIds: targetUserIds),
                    try keywordSearchCases(query: query, limit: topK, targetUserIds: targetUserIds))
        }

        var allReports = try context.fetch(FetchDescriptor<HealthReport>())
        var allCases = try context.fetch(FetchDescriptor<MedicalCase>())

        // Filter by targetUserIds if specified
        if !targetUserIds.isEmpty {
            allReports = allReports.filter { targetUserIds.contains($0.userId) }
            allCases = allCases.filter { targetUserIds.contains($0.userId) }
        }

        // Score each report by semantic similarity
        var reportScores: [(report: HealthReport, score: Double)] = []
        for report in allReports {
            let text = reportSearchText(report)
            guard !text.isEmpty else { continue }
            let dist = embedding.distance(between: query, and: text)
            // NLEmbedding.distance returns cosine distance (0 = identical, 2 = opposite)
            // Convert to similarity: 1 - (distance / 2)
            let similarity = 1.0 - (dist / 2.0)
            if similarity > 0.3 { // Threshold: filter out irrelevant results
                reportScores.append((report, similarity))
            }
        }

        // Score each case
        var caseScores: [(medCase: MedicalCase, score: Double)] = []
        for medCase in allCases {
            let text = caseSearchText(medCase)
            guard !text.isEmpty else { continue }
            let dist = embedding.distance(between: query, and: text)
            let similarity = 1.0 - (dist / 2.0)
            if similarity > 0.3 {
                caseScores.append((medCase, similarity))
            }
        }

        // Sort by similarity (highest first) and take top-K
        let topReports = reportScores.sorted { $0.score > $1.score }.prefix(topK).map(\.report)
        let topCases = caseScores.sorted { $0.score > $1.score }.prefix(topK).map(\.medCase)

        // If semantic search found nothing, fall back to keyword
        if topReports.isEmpty && topCases.isEmpty {
            return (try keywordSearchReports(query: query, limit: topK, targetUserIds: targetUserIds),
                    try keywordSearchCases(query: query, limit: topK, targetUserIds: targetUserIds))
        }

        return (Array(topReports), Array(topCases))
    }

    /// Build searchable text for a report (title + notes + OCR content)
    private func reportSearchText(_ report: HealthReport) -> String {
        var parts = [report.title]
        if let h = report.hospitalName { parts.append(h) }
        if let n = report.notes { parts.append(n) }
        if let ai = report.aiAnalysis { parts.append(ai) }
        for file in report.files {
            if let ocr = file.ocrText {
                // Truncate long OCR text to avoid NLEmbedding issues
                parts.append(String(ocr.prefix(500)))
            }
        }
        return parts.joined(separator: " ")
    }

    /// Build searchable text for a case (title + diagnosis + symptoms)
    private func caseSearchText(_ c: MedicalCase) -> String {
        var parts = [c.title]
        if let d = c.diagnosis { parts.append(d) }
        if !c.symptoms.isEmpty { parts.append(c.symptoms.joined(separator: " ")) }
        if let h = c.hospitalName { parts.append(h) }
        return parts.joined(separator: " ")
    }

    // MARK: - Keyword Search Fallback

    private func keywordSearchReports(query: String, limit: Int, targetUserIds: [UUID]) throws -> [HealthReport] {
        var all = try context.fetch(FetchDescriptor<HealthReport>())
        guard !query.isEmpty else { return [] }
        if !targetUserIds.isEmpty {
            all = all.filter { targetUserIds.contains($0.userId) }
        }
        return Array(all.filter {
            $0.title.localizedStandardContains(query) ||
            ($0.hospitalName?.localizedStandardContains(query) ?? false) ||
            ($0.notes?.localizedStandardContains(query) ?? false) ||
            $0.files.contains { $0.ocrText?.localizedStandardContains(query) ?? false }
        }.prefix(limit))
    }

    private func keywordSearchCases(query: String, limit: Int, targetUserIds: [UUID]) throws -> [MedicalCase] {
        var all = try context.fetch(FetchDescriptor<MedicalCase>())
        guard !query.isEmpty else { return [] }
        if !targetUserIds.isEmpty {
            all = all.filter { targetUserIds.contains($0.userId) }
        }
        return Array(all.filter {
            $0.title.localizedStandardContains(query) ||
            ($0.diagnosis?.localizedStandardContains(query) ?? false) ||
            $0.symptoms.contains { $0.localizedStandardContains(query) }
        }.prefix(limit))
    }

    // MARK: - Data Fetching Helpers

    private func fetchReport(id: UUID) throws -> HealthReport? {
        let targetId = id
        let descriptor = FetchDescriptor<HealthReport>()
        return try context.fetch(descriptor).first { $0.id == targetId }
    }

    private func fetchCase(id: UUID) throws -> MedicalCase? {
        let targetId = id
        let descriptor = FetchDescriptor<MedicalCase>()
        return try context.fetch(descriptor).first { $0.id == targetId }
    }

    private func fetchRecentReports(limit: Int, targetUserIds: [UUID]) throws -> [HealthReport] {
        var descriptor = FetchDescriptor<HealthReport>(
            sortBy: [SortDescriptor(\.reportDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        var results = try context.fetch(descriptor)
        if !targetUserIds.isEmpty {
            results = results.filter { targetUserIds.contains($0.userId) }
        }
        return results
    }

    private func fetchRecentCases(limit: Int, targetUserIds: [UUID]) throws -> [MedicalCase] {
        var descriptor = FetchDescriptor<MedicalCase>(
            sortBy: [SortDescriptor(\.visitDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        var results = try context.fetch(descriptor)
        if !targetUserIds.isEmpty {
            results = results.filter { targetUserIds.contains($0.userId) }
        }
        return results
    }

    private func fetchRecentHealthKitData() throws -> [HealthKitRecord] {
        var descriptor = FetchDescriptor<HealthKitRecord>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 50
        return try context.fetch(descriptor)
    }

    // MARK: - Helpers

    /// Look up user name by UUID
    private func userName(for userId: UUID) -> String {
        let allUsers = (try? context.fetch(FetchDescriptor<User>())) ?? []
        return allUsers.first(where: { $0.id == userId })?.name ?? "未知"
    }

    private func formatReport(_ report: HealthReport) -> String {
        let owner = userName(for: report.userId)
        var s = "📋 **\(report.title)** (\(report.reportType.displayName)) — \(owner)\n"
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
        let owner = userName(for: c.userId)
        var s = "🏥 **\(c.title)** — \(owner)\n"
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
