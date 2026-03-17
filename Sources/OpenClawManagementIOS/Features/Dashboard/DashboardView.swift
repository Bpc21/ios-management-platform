import SwiftUI
import OpenClawKit

struct DashboardView: View {
    @Environment(GatewayService.self) private var gateway
    
    var body: some View {
        ScrollView {
            VStack(spacing: OC.Spacing.xl) {
                
                // Stat Cards Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: OC.Spacing.md) {
                    StatCard(
                        title: "NODES",
                        value: "\(gateway.presence.count)",
                        icon: "server.rack",
                        color: OC.Colors.accent
                    )
                    
                    StatCard(
                        title: "OPERATORS",
                        value: "\(gateway.presence.filter { $0.roles?.contains("operator") == true }.count)",
                        icon: "person.2.fill",
                        color: OC.Colors.textSecondary
                    )
                    
                    StatCard(
                        title: "HEALTH",
                        value: "Healthy",
                        icon: "heart.fill",
                        color: OC.Colors.success
                    )
                    
                    StatCard(
                        title: "UPTIME",
                        value: uptimeString,
                        icon: "clock",
                        color: OC.Colors.textSecondary
                    )
                }
                .padding(.horizontal, OC.Spacing.md)
                .padding(.top, OC.Spacing.lg)
                
                // Presence List
                VStack(alignment: .leading, spacing: OC.Spacing.md) {
                    HStack {
                        Text("CONNECTED PRESENCE")
                            .font(OC.Typography.caption)
                            .foregroundStyle(OC.Colors.textTertiary)
                        Spacer()
                    }
                    
                    if gateway.presence.isEmpty {
                        Text("No connected nodes.")
                            .font(OC.Typography.body)
                            .foregroundStyle(OC.Colors.textTertiary)
                            .padding(.vertical, OC.Spacing.xl)
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        ForEach(gateway.presence.prefix(5), id: \.ts) { entry in
                            HStack {
                                Circle()
                                    .fill(OC.Colors.success)
                                    .frame(width: 8, height: 8)
                                
                                Text(entry.host ?? entry.deviceid ?? "Unknown")
                                    .font(OC.Typography.bodyMedium)
                                
                                Spacer()
                                
                                Text(entry.platform ?? "—")
                                    .font(OC.Typography.monoSmall)
                                    .foregroundStyle(OC.Colors.textTertiary)
                            }
                            .padding(.vertical, OC.Spacing.sm)
                            Divider().background(OC.Colors.border)
                        }
                    }
                }
                .ocCard()
                .padding(.horizontal, OC.Spacing.md)
                
            }
        }
    }
    
    private var uptimeString: String {
        // Mock fallback formatting; in reality, we check gateway properties
        guard gateway.connectionState.isConnected else { return "--" }
        return "Connected"
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: OC.Spacing.md) {
            HStack {
                Text(title)
                    .font(OC.Typography.caption)
                    .foregroundStyle(OC.Colors.textTertiary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(color)
            }
            
            Text(value)
                .font(OC.Typography.hero)
                .foregroundStyle(OC.Colors.textPrimary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .ocCard()
    }
}
