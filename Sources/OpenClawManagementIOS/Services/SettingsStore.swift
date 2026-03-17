import Foundation

enum ConnectionMode: String, CaseIterable, Codable {
    case local
    case remote
}

enum RemoteTransport: String, CaseIterable, Codable {
    case direct
    case sshTunnel
}

protocol SecureStringStore {
    func loadString(account: String) -> String?
    func saveString(_ value: String, account: String)
    func deleteString(account: String)
}

struct KeychainSecureStringStore: SecureStringStore {
    let service: String

    func loadString(account: String) -> String? {
        KeychainStore.loadString(service: service, account: account)
    }

    func saveString(_ value: String, account: String) {
        _ = KeychainStore.saveString(value, service: service, account: account)
    }

    func deleteString(account: String) {
        _ = KeychainStore.delete(service: service, account: account)
    }
}

final class InMemorySecureStringStore: SecureStringStore {
    private var values: [String: String] = [:]

    func loadString(account: String) -> String? {
        values[account]
    }

    func saveString(_ value: String, account: String) {
        values[account] = value
    }

    func deleteString(account: String) {
        values.removeValue(forKey: account)
    }
}

private let remoteAllowedSchemes: Set<String> = ["ws", "wss"]

@MainActor
@Observable
final class SettingsStore {
    
    private static let keychainService = "ai.openclaw.management"
    private static let legacyGatewayKeychainService = "ai.openclaw.gateway"
    private static let tokenAccount = "gateway-token"
    private static let instanceIdAccount = "instance-id"
    private static let legacyGatewayImportAttemptVersionKey = "migration.iosGatewayImportAttemptVersion"
    private static let legacyGatewayImportSchemaVersion = 1

    private let defaults: UserDefaults
    private let secureStore: any SecureStringStore

    var gatewayHost: String {
        didSet { defaults.set(gatewayHost, forKey: "gateway.host") }
    }

    var gatewayPort: Int {
        didSet { defaults.set(gatewayPort, forKey: "gateway.port") }
    }

    var gatewayUseTLS: Bool {
        didSet { defaults.set(gatewayUseTLS, forKey: "gateway.useTLS") }
    }

    var connectionMode: ConnectionMode {
        didSet { defaults.set(connectionMode.rawValue, forKey: "gateway.connectionMode") }
    }

    var remoteTransport: RemoteTransport {
        didSet { defaults.set(remoteTransport.rawValue, forKey: "gateway.remote.transport") }
    }

    var remoteURL: String {
        didSet { defaults.set(remoteURL, forKey: "gateway.remote.url") }
    }

    var remoteSSHTarget: String {
        didSet { defaults.set(remoteSSHTarget, forKey: "gateway.remote.sshTarget") }
    }

    var tailscaleMode: String {
        didSet { defaults.set(tailscaleMode, forKey: "gateway.tailscale.mode") }
    }

    var autoConnect: Bool {
        didSet { defaults.set(autoConnect, forKey: "gateway.autoConnect") }
    }

    var gatewayClientIdOverride: String {
        didSet { defaults.set(gatewayClientIdOverride, forKey: "gateway.clientIdOverride") }
    }

    var isDarkMode: Bool {
        didSet { defaults.set(isDarkMode, forKey: "ui.isDarkMode") }
    }

    var miniverseEnabled: Bool {
        didSet { defaults.set(miniverseEnabled, forKey: "miniverse.enabled") }
    }

    var miniversePort: Int {
        didSet { defaults.set(miniversePort, forKey: "miniverse.port") }
    }

    init() {
        let defaults = UserDefaults.standard
        self.defaults = defaults
        self.secureStore = KeychainSecureStringStore(service: Self.keychainService)

        self.gatewayHost = defaults.string(forKey: "gateway.host") ?? ""
        self.gatewayPort = defaults.integer(forKey: "gateway.port").nonZero ?? 443
        self.gatewayUseTLS = defaults.object(forKey: "gateway.useTLS") as? Bool ?? true
        self.connectionMode = ConnectionMode(rawValue: defaults.string(forKey: "gateway.connectionMode") ?? "") ?? .local
        self.remoteTransport = RemoteTransport(rawValue: defaults.string(forKey: "gateway.remote.transport") ?? "") ?? .direct
        self.remoteURL = defaults.string(forKey: "gateway.remote.url") ?? ""
        self.remoteSSHTarget = defaults.string(forKey: "gateway.remote.sshTarget") ?? ""
        self.tailscaleMode = defaults.string(forKey: "gateway.tailscale.mode") ?? "off"
        self.autoConnect = defaults.bool(forKey: "gateway.autoConnect")
        self.gatewayClientIdOverride = defaults.string(forKey: "gateway.clientIdOverride") ?? ""
        self.isDarkMode = defaults.object(forKey: "ui.isDarkMode") as? Bool ?? true
        self.miniverseEnabled = defaults.bool(forKey: "miniverse.enabled")
        self.miniversePort = defaults.integer(forKey: "miniverse.port").nonZero ?? 4321

        self.ensureInstanceId()
        self.performLegacyIOSGatewayImportIfNeeded()
    }

    init(defaults: UserDefaults, secureStore: any SecureStringStore) {
        self.defaults = defaults
        self.secureStore = secureStore

        self.gatewayHost = defaults.string(forKey: "gateway.host") ?? ""
        self.gatewayPort = defaults.integer(forKey: "gateway.port").nonZero ?? 443
        self.gatewayUseTLS = defaults.object(forKey: "gateway.useTLS") as? Bool ?? true
        self.connectionMode = ConnectionMode(rawValue: defaults.string(forKey: "gateway.connectionMode") ?? "") ?? .local
        self.remoteTransport = RemoteTransport(rawValue: defaults.string(forKey: "gateway.remote.transport") ?? "") ?? .direct
        self.remoteURL = defaults.string(forKey: "gateway.remote.url") ?? ""
        self.remoteSSHTarget = defaults.string(forKey: "gateway.remote.sshTarget") ?? ""
        self.tailscaleMode = defaults.string(forKey: "gateway.tailscale.mode") ?? "off"
        self.autoConnect = defaults.bool(forKey: "gateway.autoConnect")
        self.gatewayClientIdOverride = defaults.string(forKey: "gateway.clientIdOverride") ?? ""
        self.isDarkMode = defaults.object(forKey: "ui.isDarkMode") as? Bool ?? true
        self.miniverseEnabled = defaults.bool(forKey: "miniverse.enabled")
        self.miniversePort = defaults.integer(forKey: "miniverse.port").nonZero ?? 4321

        self.ensureInstanceId()
        self.performLegacyIOSGatewayImportIfNeeded()
    }

    var gatewayURL: URL? {
        switch connectionMode {
        case .remote:
            let normalized = Self.normalizedRemoteURL(remoteURL)
            guard !normalized.isEmpty else { return nil }
            if normalized != remoteURL {
                remoteURL = normalized
            }
            return Self.validWebSocketURL(normalized)
        case .local:
            let host = gatewayHost.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !host.isEmpty else { return nil }
            let scheme = gatewayUseTLS ? "wss" : "ws"
            return Self.validWebSocketURL("\(scheme)://\(host):\(gatewayPort)")
        }
    }

    var gatewayURLValidationMessage: String? {
        switch connectionMode {
        case .remote:
            let normalized = Self.normalizedRemoteURL(remoteURL)
            if normalized.isEmpty {
                return "Invalid gateway URL. Set a remote URL like `wss://your-gateway.example.com`. Current value is empty."
            }
            if Self.validWebSocketURL(normalized) == nil {
                return "Invalid gateway URL `\(remoteURL)`. Expected a full websocket URL using `ws://` or `wss://`."
            }
            return nil
        case .local:
            let host = gatewayHost.trimmingCharacters(in: .whitespacesAndNewlines)
            if host.isEmpty {
                return "Invalid gateway URL. Local mode requires a gateway host."
            }
            let scheme = gatewayUseTLS ? "wss" : "ws"
            if Self.validWebSocketURL("\(scheme)://\(host):\(gatewayPort)") == nil {
                return "Invalid local gateway URL derived from host `\(gatewayHost)` and port `\(gatewayPort)`."
            }
            return nil
        }
    }

    static func normalizedRemoteURL(_ rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.contains("://") {
            return trimmed
        }
        return "wss://\(trimmed)"
    }

    static func validWebSocketURL(_ rawValue: String) -> URL? {
        let allowedSchemes: Set<String> = ["ws", "wss"]
        guard let url = URL(string: rawValue),
              let scheme = url.scheme?.lowercased(),
              allowedSchemes.contains(scheme),
              let host = url.host,
              !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }
        return url
    }

    var instanceId: String {
        if let existing = secureStore.loadString(account: Self.instanceIdAccount) {
            return existing
        }
        let fresh = UUID().uuidString
        secureStore.saveString(fresh, account: Self.instanceIdAccount)
        return fresh
    }

    func loadToken() -> String? {
        secureStore.loadString(account: Self.tokenAccount)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func saveToken(_ token: String) {
        secureStore.saveString(token, account: Self.tokenAccount)
    }

    func clearToken() {
        secureStore.deleteString(account: Self.tokenAccount)
    }

    private var hasAnyConnectionConfiguration: Bool {
        if !gatewayHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        if !remoteURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        if let token = loadToken(), !token.isEmpty { return true }
        return false
    }

    private func ensureInstanceId() {
        if secureStore.loadString(account: Self.instanceIdAccount) == nil {
            secureStore.saveString(UUID().uuidString, account: Self.instanceIdAccount)
        }
    }

    private func performLegacyIOSGatewayImportIfNeeded() {
        let attemptedVersion = defaults.integer(forKey: Self.legacyGatewayImportAttemptVersionKey)
        guard attemptedVersion < Self.legacyGatewayImportSchemaVersion else { return }
        defer {
            defaults.set(Self.legacyGatewayImportSchemaVersion, forKey: Self.legacyGatewayImportAttemptVersionKey)
        }

        guard !hasAnyConnectionConfiguration else { return }

        let legacyManualEnabled = defaults.bool(forKey: "gateway.manual.enabled")
        let legacyManualHost = defaults.string(forKey: "gateway.manual.host")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let legacyManualPort = defaults.integer(forKey: "gateway.manual.port")
        let legacyManualTLS = defaults.object(forKey: "gateway.manual.tls") as? Bool ?? true

        if legacyManualEnabled, !legacyManualHost.isEmpty {
            applyLegacyManualConnection(host: legacyManualHost, port: legacyManualPort, useTLS: legacyManualTLS)
        } else {
            let lastKind = defaults.string(forKey: "gateway.last.kind")?.trimmingCharacters(in: .whitespacesAndNewlines)
            let lastHost = defaults.string(forKey: "gateway.last.host")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let lastPort = defaults.integer(forKey: "gateway.last.port")
            let lastTLS = defaults.object(forKey: "gateway.last.tls") as? Bool ?? legacyManualTLS

            if (lastKind == "manual" || lastKind == nil), !lastHost.isEmpty {
                applyLegacyManualConnection(host: lastHost, port: lastPort, useTLS: lastTLS)
            }
        }

        if let legacyAutoConnect = defaults.object(forKey: "gateway.autoconnect") as? Bool {
            autoConnect = legacyAutoConnect
        } else if gatewayURL != nil {
            // Preserve prior iOS behavior where gateway reconnect was typically automatic.
            autoConnect = true
        }

        let legacyClientId = defaults.string(forKey: "gateway.manual.clientId")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !legacyClientId.isEmpty {
            gatewayClientIdOverride = legacyClientId
        }

        let legacyInstanceID = defaults.string(forKey: "node.instanceId")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !legacyInstanceID.isEmpty, loadToken()?.isEmpty ?? true {
            let legacyTokenAccount = "gateway-token.\(legacyInstanceID)"
            if let legacyToken = KeychainStore.loadString(
                service: Self.legacyGatewayKeychainService,
                account: legacyTokenAccount
            )?.trimmingCharacters(in: .whitespacesAndNewlines),
               !legacyToken.isEmpty
            {
                saveToken(legacyToken)
            }
        }
    }

    private func applyLegacyManualConnection(host: String, port: Int, useTLS: Bool) {
        let resolvedPort = (1...65535).contains(port) ? port : (useTLS ? 443 : 18789)
        if host.contains("://") {
            let normalized = Self.normalizedRemoteURL(host)
            if Self.validWebSocketURL(normalized) != nil {
                connectionMode = .remote
                remoteTransport = .direct
                remoteURL = normalized
                gatewayHost = ""
                gatewayPort = resolvedPort
                gatewayUseTLS = useTLS
                return
            }
        }

        connectionMode = .local
        gatewayHost = host
        gatewayPort = resolvedPort
        gatewayUseTLS = useTLS
    }
}

private extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}
