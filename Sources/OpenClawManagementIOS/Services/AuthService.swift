import CommonCrypto
import Foundation
import Security
import SwiftData

// MARK: - Password Hashing (PBKDF2-SHA256)

enum PasswordHasher {
    private static let iterations: UInt32 = 310_000
    private static let keyLength = 32

    static func generateSalt() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    static func hash(password: String, salt: String) -> String {
        let passwordData = Array(password.utf8)
        let saltData = Array(salt.utf8)
        var derivedKey = [UInt8](repeating: 0, count: keyLength)

        CCKeyDerivationPBKDF(
            CCPBKDFAlgorithm(kCCPBKDF2),
            passwordData, passwordData.count,
            saltData, saltData.count,
            CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
            iterations,
            &derivedKey, keyLength)

        return derivedKey.map { String(format: "%02x", $0) }.joined()
    }

    static func verify(password: String, salt: String, expectedHash: String) -> Bool {
        hash(password: password, salt: salt) == expectedHash
    }
}

// MARK: - Auth Service

@MainActor
@Observable
final class AuthService {
    let modelContext: ModelContext
    private let secureStore: any SecureStringStore

    private static let sessionAccount = "auth-session"
    private static let keychainService = "ai.openclaw.management"

    private(set) var currentUser: AppUser?

    var isAuthenticated: Bool { currentUser != nil }

    var needsOnboarding: Bool {
        let descriptor = FetchDescriptor<AppUser>()
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        return count == 0
    }

    var canMutate: Bool {
        guard let user = currentUser else { return false }
        return user.role != .basic
    }

    init(modelContext: ModelContext, secureStore: (any SecureStringStore)? = nil) {
        self.modelContext = modelContext
        self.secureStore = secureStore ?? KeychainSecureStringStore(service: Self.keychainService)
    }

    // MARK: - Session

    func restoreSession() {
        guard let userId = secureStore.loadString(account: Self.sessionAccount) else { return }
        let predicate = #Predicate<AppUser> { $0.id == userId }
        var descriptor = FetchDescriptor<AppUser>(predicate: predicate)
        descriptor.fetchLimit = 1
        guard let user = try? modelContext.fetch(descriptor).first else {
            // User was deleted — clear stale session
            clearSession()
            return
        }
        currentUser = user
    }

    private func persistSession(userId: String) {
        secureStore.saveString(userId, account: Self.sessionAccount)
    }

    private func clearSession() {
        secureStore.deleteString(account: Self.sessionAccount)
    }

    // MARK: - Auth

    func login(username: String, password: String) -> Bool {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let predicate = #Predicate<AppUser> { $0.username == trimmed }
        var descriptor = FetchDescriptor<AppUser>(predicate: predicate)
        descriptor.fetchLimit = 1

        guard let user = try? modelContext.fetch(descriptor).first else { return false }
        guard PasswordHasher.verify(password: password, salt: user.salt, expectedHash: user.passwordHash) else {
            return false
        }

        user.lastLoginAt = Date()
        try? modelContext.save()

        currentUser = user
        persistSession(userId: user.id)
        return true
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
    ) throws -> AppUser {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let salt = PasswordHasher.generateSalt()
        let hash = PasswordHasher.hash(password: password, salt: salt)

        let user = AppUser(
            username: trimmedUsername,
            displayName: displayName,
            passwordHash: hash,
            salt: salt,
            role: role,
            phone: phone)

        modelContext.insert(user)
        try modelContext.save()
        return user
    }

    func updateUser(
        _ user: AppUser,
        displayName: String? = nil,
        password: String? = nil,
        role: AppUserRole? = nil,
        phone: String? = nil
    ) throws {
        if let displayName { user.displayName = displayName }
        if let role { user.role = role }
        if let phone { user.phone = phone.isEmpty ? nil : phone }

        if let password, !password.isEmpty {
            let salt = PasswordHasher.generateSalt()
            user.salt = salt
            user.passwordHash = PasswordHasher.hash(password: password, salt: salt)
        }

        try modelContext.save()
    }

    func deleteUser(_ user: AppUser) throws {
        guard user.id != currentUser?.id else {
            throw AuthError.cannotDeleteSelf
        }
        modelContext.delete(user)
        try modelContext.save()
    }

    func allUsers() -> [AppUser] {
        let descriptor = FetchDescriptor<AppUser>(sortBy: [SortDescriptor(\.createdAt)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}

// MARK: - Errors

enum AuthError: LocalizedError {
    case cannotDeleteSelf

    var errorDescription: String? {
        switch self {
        case .cannotDeleteSelf: "You cannot delete your own account"
        }
    }
}
