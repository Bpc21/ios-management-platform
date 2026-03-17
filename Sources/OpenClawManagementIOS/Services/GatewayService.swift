import Foundation
import OpenClawKit
import OpenClawProtocol
import OSLog
import SwiftUI

enum ConnectionState: Sendable, Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var label: String {
        switch self {
        case .disconnected: "Disconnected"
        case .connecting: "Connecting…"
        case .connected: "Connected"
        case .error(let msg): "Error: \(msg)"
        }
    }
}

@MainActor
@Observable
final class GatewayService {
    private static let logger = Logger(subsystem: "ai.openclaw.management", category: "gateway")

    let session = GatewayNodeSession()
    private(set) var connectionState: ConnectionState = .disconnected
    private(set) var snapshot: Snapshot?
    private(set) var presence: [PresenceEntry] = []
    var agents: [AgentSummary] = []
    private(set) var recentEvents: [EventFrame] = []
    private(set) var serverName: String?
    private(set) var remoteAddress: String?
    private(set) var uptimeMs: Int = 0

    private var eventTask: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?
    private var retryDelay: TimeInterval = 1.0
    private weak var lastSettings: SettingsStore?

    func connect(settings: SettingsStore) async {
        self.lastSettings = settings
        self.retryTask?.cancel()
        self.retryTask = nil
        
        guard let url = settings.gatewayURL else {
            self.connectionState = .error("Invalid gateway URL")
            return
        }

        let token = settings.loadToken()
        self.connectionState = .connecting

        let options = GatewayConnectOptions(
            role: "operator",
            scopes: [
                "operator.admin",
                "operator.read",
                "operator.write",
                "operator.approvals",
                "operator.pairing",
                "operator.talk",
            ],
            caps: [],
            commands: [],
            permissions: [:],
            // Gateway schema validates client.id against known constants.
            clientId: "openclaw-macos",
            clientMode: "ui",
            clientDisplayName: "OpenClaw macOS")

        do {
            try await self.session.connect(
                url: url,
                token: token,
                password: nil,
                connectOptions: options,
                sessionBox: nil,
                onConnected: { [weak self] in
                    await MainActor.run {
                        self?.handleConnected()
                    }
                },
                onDisconnected: { [weak self] reason in
                    await MainActor.run {
                        self?.handleDisconnected(reason)
                    }
                },
                onInvoke: { request in
                    // Management app doesn't handle node invocations
                    BridgeInvokeResponse(
                        id: request.id,
                        ok: false,
                        error: OpenClawNodeError(code: .unavailable, message: "not a node"))
                })
        } catch {
            let message = Self.friendlyConnectionErrorMessage(error.localizedDescription)
            self.connectionState = .error(message)
            Self.logger.error("Connect failed: \(message, privacy: .public)")
        }
    }

    func disconnect() async {
        self.eventTask?.cancel()
        self.eventTask = nil
        await self.session.disconnect()
        self.connectionState = .disconnected
        self.snapshot = nil
        self.presence = []
        self.recentEvents = []
        self.serverName = nil
        self.remoteAddress = nil
    }

    func clearError() {
        if case .error = self.connectionState {
            self.connectionState = .disconnected
        }
    }

    // MARK: - Typed Requests

    func request<T: Decodable>(method: String, paramsJSON: String? = nil, timeout: Int = 15) async throws -> T {
        let data = try await self.session.request(method: method, paramsJSON: paramsJSON, timeoutSeconds: timeout)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func requestRaw(method: String, paramsJSON: String? = nil, timeout: Int = 15) async throws -> Data {
        try await self.session.request(method: method, paramsJSON: paramsJSON, timeoutSeconds: timeout)
    }

    // MARK: - Event Subscription

    func subscribeEvents() -> AsyncStream<EventFrame> {
        // Note: subscribeServerEvents is async because GatewayNodeSession is an actor
        // We need to create the stream on the caller's context
        AsyncStream { continuation in
            let session = self.session
            Task {
                let stream = await session.subscribeServerEvents()
                for await event in stream {
                    continuation.yield(event)
                }
                continuation.finish()
            }
        }
    }

    // MARK: - Private

    private func handleConnected() {
        self.connectionState = .connected
        self.retryDelay = 1.0
        Self.logger.info("Connected to gateway")
        self.startEventMonitoring()
        
        // Fetch agents list
        Task {
            do {
                let data = try await self.session.request(method: "agents.list", paramsJSON: "{}", timeoutSeconds: 15)
                let res = try JSONDecoder().decode(AgentsListResult.self, from: data)
                await MainActor.run {
                    self.agents = res.agents
                }
            } catch {
                Self.logger.error("Failed to fetch agents: \(error.localizedDescription)")
            }
        }
    }

    private func handleDisconnected(_ reason: String) {
        let friendlyReason = Self.friendlyConnectionErrorMessage(reason)
        if friendlyReason != reason {
            self.connectionState = .error(friendlyReason)
        } else {
            self.connectionState = .disconnected
        }
        self.serverName = nil
        Self.logger.info("Disconnected: \(reason, privacy: .public)")
        
        // Auto-reconnect if not a manual close
        if self.connectionState == .disconnected,
           reason != "manually closed",
           reason != "normal closure"
        {
            self.scheduleReconnect()
        }
    }

    private func scheduleReconnect() {
        self.retryTask?.cancel()
        self.retryTask = Task { [weak self] in
            guard let self, let settings = self.lastSettings else { return }
            
            Self.logger.info("Scheduling reconnect in \(self.retryDelay)s")
            try? await Task.sleep(for: .seconds(self.retryDelay))
            
            if Task.isCancelled { return }
            
            self.retryDelay = min(self.retryDelay * 2, 30.0)
            
            Self.logger.info("Retrying connection...")
            await self.connect(settings: settings)
        }
    }

    private func startEventMonitoring() {
        self.eventTask?.cancel()
        self.eventTask = Task { [weak self] in
            guard let self else { return }
            let stream = await self.session.subscribeServerEvents()
            for await event in stream {
                if Task.isCancelled { return }
                await MainActor.run {
                    self.handleEvent(event)
                }
            }
        }
    }

    private func handleEvent(_ event: EventFrame) {
        switch event.event {
        case "presence":
            if let payload = event.payload,
               let data = try? JSONEncoder().encode(payload),
               let entries = try? JSONDecoder().decode([PresenceEntry].self, from: data)
            {
                self.presence = entries
            }
        case "health":
            // Health frames are high-frequency keepalive noise; no app state changes here.
            break
        default:
            self.recentEvents.append(event)
            if self.recentEvents.count > 1000 {
                self.recentEvents.removeFirst(100)
            }
            break
        }
    }

    private static func friendlyConnectionErrorMessage(_ message: String) -> String {
        let lower = message.lowercased()
        if lower.contains("/client/id")
            || lower.contains("invalid connect params")
            || lower.contains("must be equal to constant")
            || lower.contains("must match a schema in anyof")
        {
            return "\(message)\nHint: this gateway validates connect `client.id`. Use a supported client id (this app uses `openclaw-macos`)."
        }
        return message
    }
}
