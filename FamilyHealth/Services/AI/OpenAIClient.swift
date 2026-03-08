import Foundation

/// OpenAI-compatible API client supporting streaming responses.
/// Works with OpenAI, Claude (via proxy), Gemini, Ollama, and any
/// OpenAI-compatible endpoint.
actor OpenAIClient {
    struct ChatRequest: Encodable {
        let model: String
        let messages: [Message]
        let stream: Bool

        struct Message: Encodable {
            let role: String
            let content: String
        }
    }

    struct ChatResponse: Decodable {
        let choices: [Choice]
        struct Choice: Decodable {
            let message: MessageContent?
            let delta: MessageContent?
            struct MessageContent: Decodable {
                let content: String?
            }
        }
    }

    struct ErrorResponse: Decodable {
        let error: ErrorDetail
        struct ErrorDetail: Decodable {
            let message: String
        }
    }

    // MARK: - Non-streaming

    func chat(
        endpoint: String,
        apiKey: String,
        model: String,
        messages: [(role: String, content: String)]
    ) async throws -> String {
        let url = URL(string: endpoint.hasSuffix("/")
            ? endpoint + "chat/completions"
            : endpoint + "/chat/completions")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120

        let body = ChatRequest(
            model: model,
            messages: messages.map { .init(role: $0.role, content: $0.content) },
            stream: false
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            if let errorResp = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw AIError.apiError(errorResp.error.message)
            }
            throw AIError.httpError(httpResponse.statusCode)
        }

        let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
        return chatResponse.choices.first?.message?.content ?? ""
    }

    // MARK: - Streaming

    func chatStream(
        endpoint: String,
        apiKey: String,
        model: String,
        messages: [(role: String, content: String)]
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let url = URL(string: endpoint.hasSuffix("/")
                        ? endpoint + "chat/completions"
                        : endpoint + "/chat/completions")!

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.timeoutInterval = 300

                    let body = ChatRequest(
                        model: model,
                        messages: messages.map { .init(role: $0.role, content: $0.content) },
                        stream: true
                    )
                    request.httpBody = try JSONEncoder().encode(body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200 else {
                        throw AIError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let jsonStr = String(line.dropFirst(6))
                        if jsonStr == "[DONE]" { break }

                        guard let jsonData = jsonStr.data(using: .utf8),
                              let chunk = try? JSONDecoder().decode(ChatResponse.self, from: jsonData),
                              let content = chunk.choices.first?.delta?.content else { continue }

                        continuation.yield(content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Test Connection

    func testConnection(endpoint: String, apiKey: String, model: String) async throws -> Bool {
        let _ = try await chat(
            endpoint: endpoint,
            apiKey: apiKey,
            model: model,
            messages: [("user", "Say hello in 5 words.")]
        )
        return true
    }
}

enum AIError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case noAPIKey
    case noModelConfig

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "无效的服务器响应"
        case .httpError(let code): return "HTTP 错误: \(code)"
        case .apiError(let msg): return "API 错误: \(msg)"
        case .noAPIKey: return "未找到 API Key，请在设置中配置"
        case .noModelConfig: return "未配置 AI 模型，请在设置中添加"
        }
    }
}
