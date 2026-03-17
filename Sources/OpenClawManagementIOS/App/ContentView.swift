import SwiftUI

enum MainTab: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case agents = "Agents"
    case sessions = "Sessions"
    case chat = "Chat"
    case users = "Users"
    case settings = "Settings"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .dashboard: return "squareshape.split.2x2"
        case .agents: return "cpu"
        case .sessions: return "waveform.path.ecg"
        case .chat: return "bubble.left.and.bubble.right"
        case .users: return "person.2.fill"
        case .settings: return "network"
        }
    }

    static func allowed(for role: AppUserRole) -> [MainTab] {
        switch role {
        case .admin:
            [.dashboard, .agents, .sessions, .chat, .users, .settings]
        case .operator:
            [.dashboard, .agents, .sessions, .chat]
        case .basic:
            [.dashboard, .agents, .sessions]
        }
    }
}

struct ContentView: View {
    @State private var selectedTab: MainTab = .dashboard
    @Environment(GatewayService.self) private var gateway
    @Environment(AuthService.self) private var auth
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                VStack(alignment: .leading, spacing: OC.Spacing.xs) {
                    Text("Gateway Manager")
                        .font(OC.Typography.h2)
                        .foregroundStyle(OC.Colors.textPrimary)
                    if let user = auth.currentUser {
                        Text("\(user.displayName) · \(user.role.label)")
                            .font(OC.Typography.caption)
                            .foregroundStyle(OC.Colors.textTertiary)
                    }
                }
                
                Spacer()
                
                // Connection Status Pulse
                Circle()
                    .fill(gatewayStatusColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: gatewayStatusColor.opacity(0.3), radius: 4)

                Button("Sign Out") {
                    auth.logout()
                }
                .font(OC.Typography.caption)
                .foregroundStyle(OC.Colors.textTertiary)
            }
            .padding(.horizontal, OC.Spacing.lg)
            .padding(.top, OC.Spacing.md)
            .padding(.bottom, OC.Spacing.sm)
            .background(OC.Colors.background.ignoresSafeArea(edges: .top))
            
            // Segmented Navigation Header (Horizontal Ribbon)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: OC.Spacing.md) {
                    ForEach(visibleTabs) { tab in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedTab = tab
                            }
                        }) {
                            HStack(spacing: OC.Spacing.xs) {
                                Image(systemName: tab.icon)
                                Text(tab.rawValue)
                                    .font(OC.Typography.bodyMedium)
                            }
                            .padding(.vertical, OC.Spacing.sm)
                            .padding(.horizontal, OC.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: OC.Radius.pill)
                                    .fill(selectedTab == tab ? OC.Colors.surfaceElevated : Color.clear)
                            )
                            .foregroundStyle(selectedTab == tab ? OC.Colors.textPrimary : OC.Colors.textTertiary)
                        }
                    }
                }
                .padding(.horizontal, OC.Spacing.lg)
                .padding(.bottom, OC.Spacing.sm)
            }
            .background(OC.Colors.background)
            
            Divider()
                .background(OC.Colors.border)
            
            // Selected Content
            ZStack {
                OC.Colors.background.ignoresSafeArea()
                
                switch selectedTab {
                case .dashboard: DashboardView()
                case .agents: AgentsView()
                case .sessions: SessionsView()
                case .chat: ChatContainerView()
                case .users: UsersView()
                case .settings: ConnectionSettingsView()
                }
            }
        }
        .onAppear {
            ensureSelectedTabIsAllowed()
        }
        .onChange(of: auth.currentUser?.role) {
            ensureSelectedTabIsAllowed()
        }
    }

    private var visibleTabs: [MainTab] {
        MainTab.allowed(for: auth.currentUser?.role ?? .basic)
    }

    private func ensureSelectedTabIsAllowed() {
        if !visibleTabs.contains(selectedTab), let first = visibleTabs.first {
            selectedTab = first
        }
    }
    
    private var gatewayStatusColor: Color {
        if gateway.connectionState.isConnected {
            return OC.Colors.success
        } else {
            return OC.Colors.destructive
        }
    }
}
