import SwiftUI
import OpenClawKit

struct NodesView: View {
    @Environment(GatewayService.self) private var gateway
    @State private var nodesService = NodesDevicesService()
    
    @State private var snapshot: NodePairingSnapshot?
    @State private var errorText: String?
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: OC.Spacing.md) {
                    
                    if let errorText {
                        Text(errorText)
                            .foregroundStyle(OC.Colors.destructive)
                            .padding(.top, OC.Spacing.xl)
                    }
                    
                    if isLoading && snapshot == nil {
                        ProgressView("Loading nodes...")
                            .padding(.top, OC.Spacing.xxl)
                    } else if let snapshot {
                        if snapshot.nodes.isEmpty {
                            Text("No nodes connected.")
                                .font(OC.Typography.bodyMedium)
                                .foregroundStyle(OC.Colors.textTertiary)
                                .padding(.top, OC.Spacing.xxl)
                        } else {
                            ForEach(snapshot.nodes, id: \.id) { node in
                                NodeRow(node: node, service: nodesService)
                            }
                        }
                        
                        // Pending Pairings Section
                        if !snapshot.pendingPairings.isEmpty {
                            VStack(alignment: .leading, spacing: OC.Spacing.sm) {
                                Text("PENDING PAIRINGS")
                                    .font(OC.Typography.caption)
                                    .foregroundStyle(OC.Colors.textTertiary)
                                    .padding(.horizontal, OC.Spacing.md)
                                    .padding(.top, OC.Spacing.lg)
                                
                                ForEach(snapshot.pendingPairings, id: \.id) { pairing in
                                    PendingPairingRow(pairing: pairing, service: nodesService, onRefresh: loadData)
                                }
                            }
                        }
                    }
                }
                .padding(OC.Spacing.md)
            }
            .navigationTitle("Nodes")
            .ocNavigationBarTitleDisplayModeInline()
            .background(OC.Colors.background)
            .task {
                loadData()
            }
            .refreshable {
                loadData()
            }
        }
    }
    
    private func loadData() {
        guard !isLoading else { return }
        isLoading = true
        errorText = nil
        Task {
            do {
                let s = try await nodesService.loadNodes(gateway: gateway)
                await MainActor.run {
                    self.snapshot = s
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorText = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

struct NodeRow: View {
    let node: NodeSummaryItem
    let service: NodesDevicesService
    
    var body: some View {
        HStack(alignment: .top, spacing: OC.Spacing.md) {
            Circle()
                .fill(node.connected ? OC.Colors.success : OC.Colors.destructive)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            
            VStack(alignment: .leading, spacing: OC.Spacing.xs) {
                Text(node.displayName)
                    .font(OC.Typography.h3)
                    .foregroundStyle(OC.Colors.textPrimary)
                
                Text(node.id)
                    .font(OC.Typography.monoSmall)
                    .foregroundStyle(OC.Colors.textTertiary)
                
                HStack {
                    Text(node.platform)
                        .font(OC.Typography.caption)
                        .foregroundStyle(OC.Colors.textSecondary)
                    
                    Text("v\(node.version)")
                        .font(OC.Typography.caption)
                        .foregroundStyle(OC.Colors.textSecondary)
                }
            }
            
            Spacer()
        }
        .ocCard()
    }
}

struct PendingPairingRow: View {
    let pairing: NodePairRequestItem
    let service: NodesDevicesService
    var onRefresh: () -> Void
    @Environment(GatewayService.self) private var gateway
    
    var body: some View {
        VStack(alignment: .leading, spacing: OC.Spacing.sm) {
            HStack {
                Text(pairing.displayName)
                    .font(OC.Typography.monoSmall)
                    .foregroundStyle(OC.Colors.textPrimary)
                Spacer()
                Text("Pending")
                    .font(OC.Typography.caption)
                    .foregroundStyle(OC.Colors.warning)
            }
            
            Text(pairing.id)
                .font(OC.Typography.monoSmall)
                .foregroundStyle(OC.Colors.textTertiary)
            
            HStack(spacing: OC.Spacing.md) {
                Button(action: {
                    Task {
                        try? await service.rejectNodePairing(gateway: gateway, requestId: pairing.id)
                        onRefresh()
                    }
                }) {
                    Text("Reject")
                        .font(OC.Typography.bodyMedium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, OC.Spacing.xs)
                        .background(OC.Colors.surfaceElevated)
                        .foregroundStyle(OC.Colors.destructive)
                        .cornerRadius(OC.Radius.sm)
                }
                
                Button(action: {
                    Task {
                        try? await service.approveNodePairing(gateway: gateway, requestId: pairing.id)
                        onRefresh()
                    }
                }) {
                    Text("Approve")
                        .font(OC.Typography.bodyMedium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, OC.Spacing.xs)
                        .background(OC.Colors.accent)
                        .foregroundStyle(.white)
                        .cornerRadius(OC.Radius.sm)
                }
            }
            .padding(.top, OC.Spacing.xs)
        }
        .ocCard()
    }
}
