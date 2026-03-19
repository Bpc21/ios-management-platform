import Foundation

enum AppUserRole: String, Codable, CaseIterable, Sendable {
    case admin
    case `operator`
    case basic

    var gatewayValue: String {
        switch self {
        case .admin: "admin"
        case .operator: "manager"
        case .basic: "viewer"
        }
    }

    static func fromGateway(_ rawValue: String?) -> AppUserRole {
        switch rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "admin":
            return .admin
        case "manager", "operator":
            return .operator
        case "viewer", "basic":
            return .basic
        default:
            return .basic
        }
    }

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

struct AppUser: Identifiable, Hashable, Codable, Sendable {
    var id: String
    var username: String
    var displayName: String
    var roleRaw: String
    var phone: String?
    var isAllowlisted: Bool
    var createdAt: Date
    var lastLoginAt: Date?
    var agentAssignments: [String]
    var permissions: [String]

    var role: AppUserRole {
        get { AppUserRole(rawValue: roleRaw) ?? .basic }
        set { roleRaw = newValue.rawValue }
    }

    init(
        id: String = UUID().uuidString,
        username: String,
        displayName: String,
        role: AppUserRole = .basic,
        phone: String? = nil,
        isAllowlisted: Bool = false,
        createdAt: Date = .now,
        lastLoginAt: Date? = nil,
        agentAssignments: [String] = [],
        permissions: [String] = []
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.roleRaw = role.rawValue
        self.phone = phone
        self.isAllowlisted = isAllowlisted
        self.createdAt = createdAt
        self.lastLoginAt = lastLoginAt
        self.agentAssignments = agentAssignments
        self.permissions = permissions
    }
}
