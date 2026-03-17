import Foundation

// MARK: - Auth Service

@MainActor
@Observable
final class AuthService {
    typealias RequestHandler = @MainActor (_ method: String, _ body: [String: Any]) async throws -> [String: Any]

    private let gateway: GatewayService
    private let settings: SettingsStore
    private let secureStore: any SecureStringStore
    private let requestHandler: RequestHandler?

    private static let sessionAccount = "auth-session-token"
    private static let cachedUserAccount = "auth-user-cache"
    private static let keychainService = "ai.openclaw.management"

    private(set) var currentUser: AppUser?
    private(set) var lastError: String?

    var isAuthenticated: Bool { currentUser != nil }

    var canMutate: Bool {
        guard let user = currentUser else { return false }
        return user.role != .basic
    }

    init(
        gateway: GatewayService,
        settings: SettingsStore,
        secureStore: (any SecureStringStore)? = nil,
        requestHandler: RequestHandler? = nil
    ) {
        self.gateway = gateway
        self.settings = settings
        self.secureStore = secureStore ?? KeychainSecureStringStore(service: Self.keychainService)
        self.requestHandler = requestHandler
    }

    // MARK: - Session

    func restoreSession() async {
        guard let token = secureStore.loadString(account: Self.sessionAccount) else {
            restoreCachedUser()
            return
        }
        do {
            try await ensureConnected()
            let user = try await fetchSessionUser(token: token)
            currentUser = user
            cacheUser(user)
            lastError = nil
        } catch AuthError.gatewayNotConnected {
            restoreCachedUser()
        } catch {
            clearSession()
            currentUser = nil
            lastError = error.localizedDescription
        }
    }

    // MARK: - Auth

    func login(username: String, password: String) async -> Bool {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, !password.isEmpty else {
            lastError = "Enter a username and password."
            return false
        }

        do {
            try await ensureConnected()
            let payload = try await requestObject(
                method: "auth.login",
                body: [
                    "username": trimmed,
                    "password": password,
                ])
            let token = try Self.extractToken(from: payload)
            let user = try Self.parseUser(from: payload)
            persistSession(token: token, user: user)
            currentUser = user
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func logout() {
        currentUser = nil
        clearSession()
    }

    // MARK: - User CRUD

    @discardableResult
    func createUser(
        username: String,
        displayName: String,
        password: String,
        role: AppUserRole,
        phone: String? = nil
    ) async throws -> AppUser {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPhone = normalizePhone(phone)

        var body: [String: Any] = [
            "username": trimmedUsername,
            "displayName": trimmedDisplayName,
            "password": password,
            "role": role.rawValue,
        ]
        if let normalizedPhone {
            body["phone"] = normalizedPhone
        }

        let payload = try await requestObject(
            method: "users.create",
            body: body)
        return try Self.parseUser(from: payload)
    }

    func updateUser(
        _ user: AppUser,
        displayName: String? = nil,
        password: String? = nil,
        role: AppUserRole? = nil,
        phone: String? = nil
    ) async throws -> AppUser {
        var body: [String: Any] = ["id": user.id]
        if let displayName {
            body["displayName"] = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let password {
            let trimmed = password.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                body["password"] = trimmed
            }
        }
        if let role {
            body["role"] = role.rawValue
        }
        if let phone {
            if let normalized = normalizePhone(phone) {
                body["phone"] = normalized
            } else {
                body["phone"] = NSNull()
            }
        }

        let payload = try await requestObject(method: "users.update", body: body)
        let updated: AppUser
        if let parsed = (try? Self.parseUserIfPresent(in: payload)) ?? nil {
            updated = parsed
        } else {
            let users = try await allUsers()
            guard let refreshed = users.first(where: { $0.id == user.id }) else {
                throw AuthError.invalidResponse("users.update succeeded but no updated user payload was returned")
            }
            updated = refreshed
        }
        if updated.id == currentUser?.id {
            currentUser = updated
            cacheUser(updated)
        }
        return updated
    }

    func deleteUser(_ user: AppUser) async throws {
        guard user.id != currentUser?.id else {
            throw AuthError.cannotDeleteSelf
        }
        _ = try await requestObject(
            method: "users.delete",
            body: ["id": user.id])
    }

    func allUsers() async throws -> [AppUser] {
        let payload = try await requestObject(method: "users.list", body: [:])
        let rawUsers: [Any]
        if let list = payload["users"] as? [Any] {
            rawUsers = list
        } else if let list = payload["list"] as? [Any] {
            rawUsers = list
        } else if let single = payload["user"] as? [String: Any] {
            rawUsers = [single]
        } else {
            rawUsers = []
        }

        return try rawUsers.map { item in
            guard let object = item as? [String: Any] else {
                throw AuthError.invalidResponse("users.list returned invalid user entry")
            }
            return try Self.parseUser(from: object)
        }
    }

    // MARK: - Private

    private func ensureConnected() async throws {
        if requestHandler != nil { return }
        if gateway.connectionState.isConnected { return }
        await gateway.connect(settings: settings)
        if !gateway.connectionState.isConnected {
            throw AuthError.gatewayNotConnected
        }
    }

    private func fetchSessionUser(token: String) async throws -> AppUser {
        let payload = try await requestObject(
            method: "auth.session",
            body: ["token": token])
        return try Self.parseUser(from: payload)
    }

    private func requestObject(method: String, body: [String: Any]) async throws -> [String: Any] {
        if let requestHandler {
            return try await requestHandler(method, authorizedBody(body, for: method))
        }
        let json = try Self.encodeJSON(authorizedBody(body, for: method))
        let data = try await gateway.requestRaw(method: method, paramsJSON: json)
        return try GatewayJSON.object(from: data)
    }

    private func authorizedBody(_ body: [String: Any], for method: String) -> [String: Any] {
        guard Self.requiresSessionToken(method: method),
              let token = secureStore.loadString(account: Self.sessionAccount)
        else {
            return body
        }

        var authorized = body
        if authorized["token"] == nil {
            authorized["token"] = token
        }
        return authorized
    }

    private static func requiresSessionToken(method: String) -> Bool {
        method.hasPrefix("users.") || method == "auth.logout"
    }

    private func persistSession(token: String, user: AppUser) {
        secureStore.saveString(token, account: Self.sessionAccount)
        cacheUser(user)
    }

    private func clearSession() {
        secureStore.deleteString(account: Self.sessionAccount)
        secureStore.deleteString(account: Self.cachedUserAccount)
    }

    private func cacheUser(_ user: AppUser) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(user),
              let text = String(data: data, encoding: .utf8)
        else {
            return
        }
        secureStore.saveString(text, account: Self.cachedUserAccount)
    }

    private func restoreCachedUser() {
        guard let text = secureStore.loadString(account: Self.cachedUserAccount),
              let data = text.data(using: .utf8)
        else {
            return
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        currentUser = try? decoder.decode(AppUser.self, from: data)
    }

    private func normalizePhone(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func encodeJSON(_ object: [String: Any]) throws -> String {
        guard JSONSerialization.isValidJSONObject(object) else {
            throw AuthError.invalidResponse("Unable to encode JSON payload")
        }
        let data = try JSONSerialization.data(withJSONObject: object, options: [])
        guard let json = String(data: data, encoding: .utf8) else {
            throw AuthError.invalidResponse("Unable to encode JSON payload")
        }
        return json
    }

    private static func extractToken(from root: [String: Any]) throws -> String {
        if let token = asString(root["token"]) {
            return token
        }
        if let auth = root["auth"] as? [String: Any], let token = asString(auth["token"]) {
            return token
        }
        throw AuthError.invalidResponse("auth.login response missing token")
    }

    private static func parseUser(from root: [String: Any]) throws -> AppUser {
        let object = (root["user"] as? [String: Any]) ?? root

        guard let id = asString(object["id"]) ?? asString(object["_id"]) else {
            throw AuthError.invalidResponse("User payload missing id")
        }

        guard let username = asString(object["username"]) else {
            throw AuthError.invalidResponse("User payload missing username")
        }

        let displayName = asString(object["displayName"])
            ?? asString(object["name"])
            ?? username

        let role = AppUserRole(rawValue: asString(object["role"]) ?? "") ?? .basic
        let phone = asString(object["phone"])
        let isAllowlisted = asBool(object["isAllowlisted"]) ?? false
        let createdAt = asDate(object["createdAt"]) ?? .now
        let lastLoginAt = asDate(object["lastLoginAt"])
        let agentAssignments = asStringArray(object["agentAssignments"])
        let permissions = asStringArray(object["permissions"])

        return AppUser(
            id: id,
            username: username.lowercased(),
            displayName: displayName,
            role: role,
            phone: phone,
            isAllowlisted: isAllowlisted,
            createdAt: createdAt,
            lastLoginAt: lastLoginAt,
            agentAssignments: agentAssignments,
            permissions: permissions)
    }

    private static func parseUserIfPresent(in root: [String: Any]) throws -> AppUser? {
        if root["user"] != nil {
            return try parseUser(from: root)
        }
        let likelyFields = ["id", "_id", "username", "displayName", "name", "role", "phone"]
        if likelyFields.contains(where: { root[$0] != nil }) {
            return try parseUser(from: root)
        }
        return nil
    }

    private static func asString(_ value: Any?) -> String? {
        if let text = value as? String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return nil
    }

    private static func asStringArray(_ value: Any?) -> [String] {
        guard let array = value as? [Any] else { return [] }
        return array.compactMap { asString($0) }
    }

    private static func asBool(_ value: Any?) -> Bool? {
        if let bool = value as? Bool { return bool }
        if let number = value as? NSNumber { return number.boolValue }
        if let text = asString(value) {
            switch text.lowercased() {
            case "true", "1", "yes", "on": return true
            case "false", "0", "no", "off": return false
            default: return nil
            }
        }
        return nil
    }

    private static func asDate(_ value: Any?) -> Date? {
        if let timestamp = value as? TimeInterval {
            return timestamp > 10_000_000_000
                ? Date(timeIntervalSince1970: timestamp / 1000)
                : Date(timeIntervalSince1970: timestamp)
        }
        if let number = value as? NSNumber {
            let timestamp = number.doubleValue
            return timestamp > 10_000_000_000
                ? Date(timeIntervalSince1970: timestamp / 1000)
                : Date(timeIntervalSince1970: timestamp)
        }
        guard let text = asString(value) else { return nil }
        return iso8601Formatter.date(from: text)
            ?? DateFormatter.cachedGatewayDateFormatter.date(from: text)
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

// MARK: - Errors

enum AuthError: LocalizedError {
    case cannotDeleteSelf
    case gatewayNotConnected
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .cannotDeleteSelf: "You cannot delete your own account"
        case .gatewayNotConnected: "Gateway is not connected. Check connection settings and token."
        case .invalidResponse(let message): message
        }
    }
}

private extension DateFormatter {
    static let cachedGatewayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return formatter
    }()
}
