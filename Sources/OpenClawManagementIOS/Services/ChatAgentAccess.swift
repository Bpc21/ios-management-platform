import Foundation
import OpenClawProtocol

enum ChatAgentAccess {
    static func visibleAgents(_ agents: [AgentSummary], for user: AppUser?) -> [AgentSummary] {
        guard let user else { return [] }

        switch user.role {
        case .admin:
            return agents
        case .operator:
            return AgentVisibilityFilter.filterAgents(agents, for: user)
        case .basic:
            let allowed = Set(user.agentAssignments)
            return agents.filter { allowed.contains($0.id) }
        }
    }

    static func sessionKey(for agentId: String?) -> String {
        guard let agentId = agentId?.trimmingCharacters(in: .whitespacesAndNewlines), !agentId.isEmpty else {
            return "main"
        }
        return "agent:\(agentId):main"
    }
}
