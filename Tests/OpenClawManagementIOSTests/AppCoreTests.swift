import XCTest
@testable import OpenClawManagementIOS

@MainActor
final class AppCoreTests: XCTestCase {
    func testSettingsStoreNormalizesRemoteURLAndRejectsInvalidSchemes() {
        let settings = makeSettings()
        settings.connectionMode = .remote
        settings.remoteURL = "gateway.tail0000.ts.net"

        XCTAssertEqual(settings.gatewayURL?.absoluteString, "wss://gateway.tail0000.ts.net")
        XCTAssertEqual(settings.remoteURL, "wss://gateway.tail0000.ts.net")

        settings.remoteURL = "https://gateway.tail0000.ts.net"
        XCTAssertNil(settings.gatewayURL)
        XCTAssertNotNil(settings.gatewayURLValidationMessage)
    }

    func testSettingsStoreBuildsLocalGatewayURL() {
        let settings = makeSettings()
        settings.connectionMode = .local
        settings.gatewayHost = "localhost"
        settings.gatewayPort = 19789
        settings.gatewayUseTLS = true
        XCTAssertEqual(settings.gatewayURL?.absoluteString, "wss://localhost:19789")

        settings.gatewayUseTLS = false
        XCTAssertEqual(settings.gatewayURL?.absoluteString, "ws://localhost:19789")
    }

    func testAuthLoginAndCachedRestoreWhenGatewayUnavailable() async {
        let settings = makeSettings()
        let secureStore = InMemorySecureStringStore()
        let auth = AuthService(
            gateway: GatewayService(),
            settings: settings,
            secureStore: secureStore,
            requestHandler: { method, body in
                switch method {
                case "auth.login":
                    XCTAssertEqual(body["username"] as? String, "alice")
                    XCTAssertEqual(body["password"] as? String, "secret")
                    return [
                        "token": "session-token",
                        "user": Self.makeUserPayload(
                            id: "u_1",
                            username: "alice",
                            role: "admin",
                            agentAssignments: ["dev-director"])
                    ]
                case "auth.session":
                    XCTAssertEqual(body["token"] as? String, "session-token")
                    return [
                        "user": Self.makeUserPayload(
                            id: "u_1",
                            username: "alice",
                            role: "admin",
                            agentAssignments: ["dev-director"])
                    ]
                default:
                    XCTFail("Unexpected method \(method)")
                    return [:]
                }
            })

        let loginSucceeded = await auth.login(username: "Alice", password: "secret")
        XCTAssertTrue(loginSucceeded)
        XCTAssertEqual(auth.currentUser?.username, "alice")
        XCTAssertEqual(auth.currentUser?.role, .admin)

        let restored = AuthService(
            gateway: GatewayService(),
            settings: settings,
            secureStore: secureStore,
            requestHandler: { _, _ in
                throw AuthError.gatewayNotConnected
            })

        await restored.restoreSession()
        XCTAssertEqual(restored.currentUser?.username, "alice")
        XCTAssertNil(restored.lastError)
    }

    func testRoleBasedTabsVisibility() {
        XCTAssertEqual(MainTab.allowed(for: .admin), [.dashboard, .agents, .sessions, .chat, .users, .settings])
        XCTAssertEqual(MainTab.allowed(for: .operator), [.dashboard, .agents, .sessions, .chat])
        XCTAssertEqual(MainTab.allowed(for: .basic), [.dashboard, .agents, .sessions])
    }

    func testLegacyIOSManualGatewaySettingsAreImported() {
        let suiteName = "OpenClawManagementIOSTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(true, forKey: "gateway.manual.enabled")
        defaults.set("gateway.tailnet.ts.net", forKey: "gateway.manual.host")
        defaults.set(443, forKey: "gateway.manual.port")
        defaults.set(true, forKey: "gateway.manual.tls")
        defaults.set(true, forKey: "gateway.autoconnect")
        defaults.set("openclaw-ios", forKey: "gateway.manual.clientId")

        let settings = SettingsStore(defaults: defaults, secureStore: InMemorySecureStringStore())

        XCTAssertEqual(settings.connectionMode, .local)
        XCTAssertEqual(settings.gatewayHost, "gateway.tailnet.ts.net")
        XCTAssertEqual(settings.gatewayPort, 443)
        XCTAssertTrue(settings.gatewayUseTLS)
        XCTAssertTrue(settings.autoConnect)
        XCTAssertEqual(settings.gatewayClientIdOverride, "openclaw-ios")
    }

    func testLegacyIOSLastManualGatewaySettingsFallbackImport() {
        let suiteName = "OpenClawManagementIOSTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set("manual", forKey: "gateway.last.kind")
        defaults.set("relay.tailnet.ts.net", forKey: "gateway.last.host")
        defaults.set(443, forKey: "gateway.last.port")
        defaults.set(true, forKey: "gateway.last.tls")

        let settings = SettingsStore(defaults: defaults, secureStore: InMemorySecureStringStore())

        XCTAssertEqual(settings.gatewayHost, "relay.tailnet.ts.net")
        XCTAssertEqual(settings.gatewayPort, 443)
        XCTAssertEqual(settings.gatewayURL?.absoluteString, "wss://relay.tailnet.ts.net:443")
    }
}

private extension AppCoreTests {
    func makeSettings() -> SettingsStore {
        let suiteName = "OpenClawManagementIOSTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SettingsStore(defaults: defaults, secureStore: InMemorySecureStringStore())
    }

    static func makeUserPayload(
        id: String,
        username: String,
        role: String,
        phone: String? = nil,
        agentAssignments: [String]
    ) -> [String: Any] {
        var payload: [String: Any] = [
            "id": id,
            "username": username,
            "displayName": username.capitalized,
            "role": role,
            "isAllowlisted": phone != nil,
            "createdAt": "2026-03-17T00:00:00Z",
            "lastLoginAt": "2026-03-17T01:00:00Z",
            "agentAssignments": agentAssignments,
            "permissions": ["operator.read"],
        ]
        payload["phone"] = phone
        return payload
    }
}
