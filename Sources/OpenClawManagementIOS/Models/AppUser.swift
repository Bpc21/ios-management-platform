import Foundation
import SwiftData

enum AppUserRole: String, Codable, CaseIterable, Sendable {
    case admin
    case `operator`
    case basic

    var label: String {
        switch self {
        case .admin: "Admin"
        case .operator: "Operator"
        case .basic: "Basic"
        }
    }

    var color: String {
        switch self {
        case .admin: "alertRed"
        case .operator: "infoBlue"
        case .basic: "textSecondary"
        }
    }
}

@Model
final class AppUser {
    @Attribute(.unique) var id: String
    @Attribute(.unique) var username: String
    var displayName: String
    var passwordHash: String
    var salt: String
    var roleRaw: String
    var phone: String?
    var isAllowlisted: Bool
    var createdAt: Date
    var lastLoginAt: Date?

    var role: AppUserRole {
        get { AppUserRole(rawValue: roleRaw) ?? .basic }
        set { roleRaw = newValue.rawValue }
    }

    init(
        id: String = UUID().uuidString,
        username: String,
        displayName: String,
        passwordHash: String,
        salt: String,
        role: AppUserRole = .basic,
        phone: String? = nil,
        isAllowlisted: Bool = false
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.passwordHash = passwordHash
        self.salt = salt
        self.roleRaw = role.rawValue
        self.phone = phone
        self.isAllowlisted = isAllowlisted
        self.createdAt = Date()
    }
}
