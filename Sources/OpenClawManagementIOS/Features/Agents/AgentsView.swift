import SwiftUI
import OpenClawKit
import OpenClawProtocol

extension AgentSummary: Identifiable {}

struct AgentsView: View {
    @Environment(GatewayService.self) private var gateway
    @State private var selectedAgent: AgentSummary?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: OC.Spacing.md) {
                    if gateway.agents.isEmpty {
                        Text("No agents found.")
                            .font(OC.Typography.bodyMedium)
                            .foregroundStyle(OC.Colors.textTertiary)
                            .padding(.top, OC.Spacing.xxl)
                    } else {
                        ForEach(gateway.agents) { agent in
                            Button {
                                selectedAgent = agent
                            } label: {
                                AgentRow(agent: agent)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(OC.Spacing.md)
            }
            .navigationTitle("Agents")
            .navigationBarHidden(true)
            .sheet(item: $selectedAgent) { agent in
                AgentDetailView(agent: agent)
            }
        }
    }
}

struct AgentRow: View {
    let agent: AgentSummary
    
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
                    // Agent Metrics
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
                    
                    // Task Log Placeholder
                    VStack(alignment: .leading, spacing: OC.Spacing.sm) {
                        Text("LATEST TASKS")
                            .font(OC.Typography.caption)
                            .foregroundStyle(OC.Colors.textTertiary)
                        
                        Text("Task history synchronization not yet implemented for iOS.")
                            .font(OC.Typography.monoSmall)
                            .foregroundStyle(OC.Colors.textTertiary)
                    }
                    .ocCard()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(OC.Spacing.md)
            }
            .background(OC.Colors.background)
            .navigationTitle(agent.name ?? "Agent Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(OC.Colors.accent)
                }
            }
        }
    }
}
