import Foundation
import OpenClawProtocol
import Observation

struct ScopeGrant: Identifiable, Hashable {
    let id: String
    let description: String
    let granted: Bool
}

struct ExecApprovalsPolicySummary: Hashable {
    let path: String
    let hash: String
    let exists: Bool
    let socketPath: String?
    let defaultAllowlistCount: Int
    let agentRuleCount: Int
}

@MainActor
@Observable
final class PermissionsDataService {
    let grantedScopes: [String]

    init(grantedScopes: [String] = [
        "operator.admin",
        "operator.read",
        "operator.write",
        "operator.approvals",
        "operator.pairing",
        "operator.talk",
    ]) {
        self.grantedScopes = grantedScopes
    }

    func scopesOverview() -> [ScopeGrant] {
        let descriptions: [String: String] = [
            "operator.admin": "Full administrative access",
            "operator.read": "Read gateway state and data",
            "operator.write": "Modify mutable gateway resources",
            "operator.approvals": "Manage command approvals",
            "operator.pairing": "Manage device and node pairing",
            "operator.talk": "Control talk/voice capabilities",
        ]

        return descriptions.keys.sorted().map { scope in
            ScopeGrant(
                id: scope,
                description: descriptions[scope] ?? "",
                granted: grantedScopes.contains(scope))
        }
    }

    func loadPolicySummary(gateway: GatewayService) async throws -> ExecApprovalsPolicySummary {
        let data = try await gateway.requestRaw(method: "exec.approvals.get", paramsJSON: "{}")
        let root = try GatewayJSON.object(from: data)

        let exists = (root["exists"] as? Bool) ?? false
        let file = root["file"] as? [String: Any] ?? [:]

        let defaults = file["defaults"] as? [String: Any] ?? [:]
        let defaultAllowlist = defaults["allowlist"] as? [Any] ?? []

        let agents = file["agents"] as? [String: Any] ?? [:]
        let agentRuleCount = agents.values.reduce(into: 0) { count, value in
            guard let entry = value as? [String: Any] else { return }
            let allowlist = entry["allowlist"] as? [Any] ?? []
            count += allowlist.count
        }

        let socketPath = GatewayJSON.string(at: ["socket", "path"], in: file)

        return ExecApprovalsPolicySummary(
            path: (root["path"] as? String) ?? "",
            hash: (root["hash"] as? String) ?? "",
            exists: exists,
            socketPath: socketPath,
            defaultAllowlistCount: defaultAllowlist.count,
            agentRuleCount: agentRuleCount)
    }
}
