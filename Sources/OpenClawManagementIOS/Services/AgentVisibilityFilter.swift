import Foundation
import OpenClawProtocol

enum AgentVisibilityFilter {
    // Shared agency/administrative agents visible to non-admin users.
    static let sharedAgentIds: Set<String> = [
        "dev-director", "dev-frontend-dev", "dev-backend-dev",
        "dev-qa-test", "dev-devops-release", "dev-security-review",
        "mkt-director", "lgl-director", "smm-director", "ops-director",
        "sales-director", "cs-director", "hr-director", "pm-director",
        "crt-director", "fin-director", "sec-director", "inf-director",
    ]

    static func filterAgents(_ agents: [AgentSummary], for user: AppUser?) -> [AgentSummary] {
        guard let user else { return [] }
        guard user.role != .admin else { return agents }
        let allowed = Set(user.agentAssignments).union(sharedAgentIds)
        return agents.filter { allowed.contains($0.id) }
    }
}
