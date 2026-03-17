import SwiftUI
import OpenClawKit

struct PermissionsView: View {
    @Environment(GatewayService.self) private var gateway
    @State private var permissionsService = PermissionsDataService()
    
    @State private var policySummary: ExecApprovalsPolicySummary?
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
                    
                    if isLoading && policySummary == nil {
                        ProgressView("Loading permissions...")
                            .padding(.top, OC.Spacing.xxl)
                    } else if let summary = policySummary {
                        
                        VStack(alignment: .leading, spacing: OC.Spacing.sm) {
                            Text("POLICY SUMMARY")
                                .font(OC.Typography.caption)
                                .foregroundStyle(OC.Colors.textTertiary)
                            
                            HStack {
                                Text("Enabled:")
                                Spacer()
                                Text(summary.exists ? "Yes" : "No")
                            }
                            HStack {
                                Text("Default Allowlist:")
                                Spacer()
                                Text("\(summary.defaultAllowlistCount) items")
                            }
                            HStack {
                                Text("Agent Rules:")
                                Spacer()
                                Text("\(summary.agentRuleCount)")
                            }
                        }
                        .ocCard()
                        
                        Text("GRANTED SCOPES")
                            .font(OC.Typography.caption)
                            .foregroundStyle(OC.Colors.textTertiary)
                            .padding(.top, OC.Spacing.md)
                        
                        ForEach(permissionsService.scopesOverview(), id: \.id) { scope in
                            HStack {
                                Text(scope.id)
                                    .font(OC.Typography.monoSmall)
                                Spacer()
                                Text(scope.description)
                                    .font(OC.Typography.caption)
                                    .foregroundStyle(OC.Colors.textSecondary)
                            }
                            .ocCard()
                        }
                    }
                }
                .padding(OC.Spacing.md)
            }
            .navigationTitle("Permissions")
            .ocNavigationBarHidden(true)
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
                let summary = try await permissionsService.loadPolicySummary(gateway: gateway)
                await MainActor.run {
                    self.policySummary = summary
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
