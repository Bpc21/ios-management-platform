import OpenClawChatUI
import OpenClawKit
import OpenClawProtocol
import Foundation
import OSLog

struct OperatorChatTransport: OpenClawChatTransport, Sendable {
    private static let logger = Logger(subsystem: "ai.openclaw.management", category: "chat.transport")
    private let gateway: GatewayNodeSession

    struct ChatSendParams: Codable, Equatable {
        var sessionKey: String
        var message: String
        var thinking: String
        var attachments: [OpenClawChatAttachmentPayload]?
        var timeoutMs: Int
        var idempotencyKey: String
    }

    init(gateway: GatewayNodeSession) {
        self.gateway = gateway
    }

    func abortRun(sessionKey: String, runId: String) async throws {
        struct Params: Codable {
            var sessionKey: String
            var runId: String
        }
        let data = try JSONEncoder().encode(Params(sessionKey: sessionKey, runId: runId))
        let json = String(data: data, encoding: .utf8)
        _ = try await self.gateway.request(method: "chat.abort", paramsJSON: json, timeoutSeconds: 10)
    }

    func listSessions(limit: Int?) async throws -> OpenClawChatSessionsListResponse {
        struct Params: Codable {
            var includeGlobal: Bool
            var includeUnknown: Bool
            var limit: Int?
        }
        let data = try JSONEncoder().encode(Params(includeGlobal: true, includeUnknown: false, limit: limit))
        let json = String(data: data, encoding: .utf8)
        let res = try await self.gateway.request(method: "sessions.list", paramsJSON: json, timeoutSeconds: 15)
        return try JSONDecoder().decode(OpenClawChatSessionsListResponse.self, from: res)
    }

    func setActiveSessionKey(_ sessionKey: String) async throws {
        // Operator clients receive chat events without node-style subscriptions.
    }

    func requestHistory(sessionKey: String) async throws -> OpenClawChatHistoryPayload {
        struct Params: Codable { var sessionKey: String }
        let data = try JSONEncoder().encode(Params(sessionKey: sessionKey))
        let json = String(data: data, encoding: .utf8)
        let res = try await self.gateway.request(method: "chat.history", paramsJSON: json, timeoutSeconds: 15)
        return try JSONDecoder().decode(OpenClawChatHistoryPayload.self, from: res)
    }

    func sendMessage(
        sessionKey: String,
        message: String,
        thinking: String,
        idempotencyKey: String,
        attachments: [OpenClawChatAttachmentPayload]) async throws -> OpenClawChatSendResponse
    {
        Self.logger.info("chat.send sessionKey=\(sessionKey, privacy: .public) len=\(message.count)")
        let params = Self.makeSendParams(
            sessionKey: sessionKey,
            message: message,
            thinking: thinking,
            attachments: attachments.isEmpty ? nil : attachments,
            timeoutMs: 30000,
            idempotencyKey: idempotencyKey)
        let data = try JSONEncoder().encode(params)
        let json = String(data: data, encoding: .utf8)
        let res = try await self.gateway.request(method: "chat.send", paramsJSON: json, timeoutSeconds: 35)
        return try JSONDecoder().decode(OpenClawChatSendResponse.self, from: res)
    }

    static func makeSendParams(
        sessionKey: String,
        message: String,
        thinking: String,
        attachments: [OpenClawChatAttachmentPayload]?,
        timeoutMs: Int,
        idempotencyKey: String
    ) -> ChatSendParams {
        ChatSendParams(
            sessionKey: sessionKey,
            message: message,
            thinking: thinking,
            attachments: attachments,
            timeoutMs: timeoutMs,
            idempotencyKey: idempotencyKey)
    }

    func requestHealth(timeoutMs: Int) async throws -> Bool {
        let seconds = max(1, Int(ceil(Double(timeoutMs) / 1000.0)))
        let res = try await self.gateway.request(method: "health", paramsJSON: nil, timeoutSeconds: seconds)
        // Note: Simple decode check for ok: true
        struct HealthRes: Codable { var ok: Bool }
        return (try? JSONDecoder().decode(HealthRes.self, from: res))?.ok ?? true
    }

    func events() -> AsyncStream<OpenClawChatTransportEvent> {
        AsyncStream { continuation in
            let task = Task {
                let stream = await self.gateway.subscribeServerEvents()
                for await evt in stream {
                    if Task.isCancelled { return }
                    switch evt.event {
                    case "tick":
                        continuation.yield(.tick)
                    case "seqGap":
                        continuation.yield(.seqGap)
                    case "health":
                        continuation.yield(.health(ok: true))
                    case "chat":
                        guard let payload = evt.payload else { break }
                        // Use a local copy of decoding logic if GatewayPayloadDecoding is missing or different
                        if let data = try? JSONEncoder().encode(payload),
                           let chatPayload = try? JSONDecoder().decode(OpenClawChatEventPayload.self, from: data)
                        {
                            continuation.yield(.chat(chatPayload))
                        }
                    case "agent":
                        guard let payload = evt.payload else { break }
                        if let data = try? JSONEncoder().encode(payload),
                           let agentPayload = try? JSONDecoder().decode(OpenClawAgentEventPayload.self, from: data)
                        {
                            continuation.yield(.agent(agentPayload))
                        }
                    default:
                        break
                    }
                }
            }
            continuation.onTermination = { @Sendable _ in task.cancel() }
        }
    }
}
