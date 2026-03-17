import SwiftUI
import OpenClawKit
import OpenClawProtocol

extension AgentSummary: @retroactive Identifiable {}

struct AgentsView: View {
    @Environment(GatewayService.self) private var gateway
    @Environment(AuthService.self) private var auth
    @State private var selectedAgent: AgentSummary?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: OC.Spacing.md) {
                    HStack {
                        Text("\(visibleAgents.count) agent(s)")
                            .font(OC.Typography.caption)
                            .foregroundStyle(OC.Colors.textTertiary)
                        Spacer()
                        Button {
                            Task { await gateway.refreshAgents() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(OC.Colors.textSecondary)
                        }
                    }
                    .padding(.horizontal, OC.Spacing.md)

                    if visibleAgents.isEmpty {
                        Text("No agents found.")
                            .font(OC.Typography.bodyMedium)
                            .foregroundStyle(OC.Colors.textTertiary)
                            .padding(.top, OC.Spacing.xxl)
                    } else {
                        ForEach(visibleAgents) { agent in
                            Button {
                                selectedAgent = agent
                            } label: {
                                AgentRow(agent: agent, isDefault: agent.id == gateway.defaultAgentId)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(OC.Spacing.md)
            }
            .navigationTitle("Agents")
            .ocNavigationBarHidden(true)
            .task(id: gateway.connectionState.isConnected) {
                guard gateway.connectionState.isConnected else { return }
                await gateway.refreshAgents()
            }
            .sheet(item: $selectedAgent) { agent in
                AgentDetailView(agent: agent)
            }
        }
    }

    private var visibleAgents: [AgentSummary] {
        AgentVisibilityFilter.filterAgents(gateway.agents, for: auth.currentUser)
    }
}

struct AgentRow: View {
    let agent: AgentSummary
    let isDefault: Bool
    
    var body: some View {
        HStack(spacing: OC.Spacing.md) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            
            VStack(alignment: .leading, spacing: OC.Spacing.xs) {
                Text(agent.name ?? agent.id)
                    .font(OC.Typography.h3)
                    .foregroundStyle(OC.Colors.textPrimary)
                
                Text(agent.id)
                    .font(OC.Typography.monoSmall)
                    .foregroundStyle(OC.Colors.textTertiary)
                    .lineLimit(1)

                if isDefault {
                    Text("DEFAULT")
                        .font(OC.Typography.caption)
                        .foregroundStyle(OC.Colors.accent)
                        .padding(.horizontal, OC.Spacing.xs)
                        .background(OC.Colors.accent.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            
            Spacer()
            
            Text("ACTIVE")
                .font(OC.Typography.caption)
                .foregroundStyle(statusColor)
                .padding(.horizontal, OC.Spacing.sm)
                .padding(.vertical, OC.Spacing.xs)
                .background(statusColor.opacity(0.1))
                .cornerRadius(OC.Radius.sm)
        }
        .ocCard()
    }
    
    private var statusColor: Color {
        return OC.Colors.success
    }
}

struct AgentDetailView: View {
    let agent: AgentSummary
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
            VStack(spacing: OC.Spacing.md) {
                    VStack(alignment: .leading, spacing: OC.Spacing.sm) {
                        Text("METADATA")
                            .font(OC.Typography.caption)
                            .foregroundStyle(OC.Colors.textTertiary)
                        
                        Text(agent.identity?["description"]?.value as? String ?? "No description available.")
                            .font(OC.Typography.body)
                            .foregroundStyle(OC.Colors.textSecondary)
                    }
                    .ocCard()
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: OC.Spacing.sm) {
                        Text("IDENTITY")
                            .font(OC.Typography.caption)
                            .foregroundStyle(OC.Colors.textTertiary)

                        identityRow("ID", value: agent.id)
                        identityRow("Name", value: agent.name ?? "—")
                        identityRow("Persona", value: agent.identity?["persona"]?.value as? String ?? "—")
                    }
                    .ocCard()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(OC.Spacing.md)
            }
            .background(OC.Colors.background)
            .navigationTitle(agent.name ?? "Agent Details")
            .ocNavigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(OC.Colors.accent)
                }
            }
        }
    }

    @ViewBuilder
    private func identityRow(_ key: String, value: String) -> some View {
        HStack {
            Text(key)
                .font(OC.Typography.caption)
                .foregroundStyle(OC.Colors.textTertiary)
            Spacer()
            Text(value)
                .font(OC.Typography.monoSmall)
                .foregroundStyle(OC.Colors.textPrimary)
                .lineLimit(1)
        }
    }
}
