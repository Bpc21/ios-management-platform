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

@MainActor
@Observable
final class SettingsStore {
    static let shared = SettingsStore()
    
    private static let keychainService = "ai.openclaw.management"
    private static let tokenAccount = "gateway-token"
    private static let instanceIdAccount = "instance-id"

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
        self.isDarkMode = defaults.object(forKey: "ui.isDarkMode") as? Bool ?? true
        self.miniverseEnabled = defaults.bool(forKey: "miniverse.enabled")
        self.miniversePort = defaults.integer(forKey: "miniverse.port").nonZero ?? 4321

        self.ensureInstanceId()
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
        self.isDarkMode = defaults.object(forKey: "ui.isDarkMode") as? Bool ?? true
        self.miniverseEnabled = defaults.bool(forKey: "miniverse.enabled")
        self.miniversePort = defaults.integer(forKey: "miniverse.port").nonZero ?? 4321

        self.ensureInstanceId()
    }

    var gatewayURL: URL? {
        switch connectionMode {
        case .remote:
            let trimmedRemoteURL = remoteURL.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedRemoteURL.isEmpty else { return nil }
            return URL(string: trimmedRemoteURL)
        case .local:
            let host = gatewayHost.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !host.isEmpty else { return nil }
            let scheme = gatewayUseTLS ? "wss" : "ws"
            return URL(string: "\(scheme)://\(host):\(gatewayPort)")
        }
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
}

private extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}
