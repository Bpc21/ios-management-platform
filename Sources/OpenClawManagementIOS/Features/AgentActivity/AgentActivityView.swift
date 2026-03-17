import SwiftUI
import OpenClawProtocol

struct AgentActivityView: View {
    @Environment(GatewayService.self) private var gateway
    @Environment(OperationalCoreStore.self) private var core

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: OC.Spacing.md) {
                    summaryCards

                    if activityRows.isEmpty {
                        Text("No active agent activity available.")
                            .font(OC.Typography.bodyMedium)
                            .foregroundStyle(OC.Colors.textTertiary)
                            .padding(.top, OC.Spacing.xl)
                    } else {
                        ForEach(activityRows, id: \.agentId) { row in
                            AgentActivityRowView(row: row)
                        }
                    }
                }
                .padding(OC.Spacing.md)
            }
            .background(OC.Colors.background)
            .navigationTitle("Agent Activity")
            .ocNavigationBarTitleDisplayModeInline()
            .task(id: gateway.connectionState.isConnected) {
                guard gateway.connectionState.isConnected else { return }
                await gateway.refreshAgents()
            }
        }
    }

    private var summaryCards: some View {
        HStack(spacing: OC.Spacing.md) {
            metric(title: "AGENTS", value: "\(gateway.agents.count)")
            metric(title: "PRESENCE", value: "\(gateway.presence.count)")
            metric(title: "ACTIVE TASKS", value: "\(activeTaskCount)")
        }
    }

    private var activeTaskCount: Int {
        core.tasks.filter { $0.status != .done }.count
    }

    private var activityRows: [AgentActivityRow] {
        let taskGroups = Dictionary(grouping: core.tasks.filter { $0.status != .done }) { $0.assignedAgentId ?? "unassigned" }

        let byKnownAgent = gateway.agents.map { agent in
            AgentActivityRow(
                agentId: agent.id,
                displayName: agent.name ?? agent.id,
                taskCount: taskGroups[agent.id]?.count ?? 0,
                currentStatus: presenceStatus(for: agent.id),
                latestUpdate: latestPresenceTimestamp(for: agent.id)
            )
        }

        let orphanTaskAgentIds = Set(taskGroups.keys).subtracting(gateway.agents.map(\.id))
        let orphans = orphanTaskAgentIds.map { agentId in
            AgentActivityRow(
                agentId: agentId,
                displayName: agentId == "unassigned" ? "Unassigned" : agentId,
                taskCount: taskGroups[agentId]?.count ?? 0,
                currentStatus: agentId == "unassigned" ? "No assignee" : "Unknown agent",
                latestUpdate: nil
            )
        }

        return (byKnownAgent + orphans)
            .filter { $0.taskCount > 0 || $0.latestUpdate != nil }
            .sorted { lhs, rhs in
                if lhs.taskCount == rhs.taskCount {
                    return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
                }
                return lhs.taskCount > rhs.taskCount
            }
    }

    private func presenceEntries(for agentId: String) -> [PresenceEntry] {
        gateway.presence.filter { entry in
            let tags = entry.tags ?? []
            if tags.contains(agentId) {
                return true
            }
            if entry.instanceid == agentId {
                return true
            }
            return (entry.text ?? "").localizedCaseInsensitiveContains(agentId)
        }
    }

    private func presenceStatus(for agentId: String) -> String {
        let entries = presenceEntries(for: agentId)
        if entries.isEmpty {
            return "Idle"
        }

        if let mode = entries.first(where: { ($0.mode ?? "").isEmpty == false })?.mode {
            return mode.capitalized
        }

        return "Active"
    }

    private func latestPresenceTimestamp(for agentId: String) -> Date? {
        let latest = presenceEntries(for: agentId).max(by: { $0.ts < $1.ts })
        guard let ts = latest?.ts else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(ts) / 1000)
    }

    @ViewBuilder
    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: OC.Spacing.xs) {
            Text(title)
                .font(OC.Typography.caption)
                .foregroundStyle(OC.Colors.textTertiary)
            Text(value)
                .font(OC.Typography.h2)
                .foregroundStyle(OC.Colors.textPrimary)
        }
        .ocCard()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AgentActivityRow: Hashable {
    let agentId: String
    let displayName: String
    let taskCount: Int
    let currentStatus: String
    let latestUpdate: Date?
}

private struct AgentActivityRowView: View {
    let row: AgentActivityRow

    var body: some View {
        VStack(alignment: .leading, spacing: OC.Spacing.xs) {
            HStack {
                Text(row.displayName)
                    .font(OC.Typography.bodyMedium)
                    .foregroundStyle(OC.Colors.textPrimary)
                Spacer()
                Text("\(row.taskCount) task(s)")
                    .font(OC.Typography.caption)
                    .foregroundStyle(OC.Colors.textSecondary)
            }

            HStack {
                Text(row.currentStatus)
                    .font(OC.Typography.caption)
                    .foregroundStyle(OC.Colors.accent)
                Spacer()
                if let latestUpdate = row.latestUpdate {
                    Text(latestUpdate.formatted(date: .abbreviated, time: .shortened))
                        .font(OC.Typography.caption)
                        .foregroundStyle(OC.Colors.textTertiary)
                }
            }

            Text(row.agentId)
                .font(OC.Typography.monoSmall)
                .foregroundStyle(OC.Colors.textTertiary)
                .lineLimit(1)
        }
        .ocCard()
    }
}
