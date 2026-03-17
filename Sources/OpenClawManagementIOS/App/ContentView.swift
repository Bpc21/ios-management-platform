import SwiftUI

enum MainTab: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case agents = "Agents"
    case sessions = "Sessions"
    case chat = "Chat"
    case voice = "Voice"
    case monitoring = "Monitoring"
    case logs = "Logs"
    case cron = "Cron"
    case nodes = "Nodes"
    case devices = "Devices"
    case users = "Users"
    case permissions = "Permissions"
    case skills = "Skills"
    case tools = "Tools"
    case settings = "Settings"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .dashboard: return "squareshape.split.2x2"
        case .agents: return "cpu"
        case .sessions: return "waveform.path.ecg"
        case .chat: return "bubble.left.and.bubble.right"
        case .voice: return "mic.fill"
        case .monitoring: return "chart.line.uptrend.xyaxis"
        case .logs: return "doc.text.magnifyingglass"
        case .cron: return "timer"
        case .nodes: return "server.rack"
        case .devices: return "display"
        case .users: return "person.2.fill"
        case .permissions: return "key.fill"
        case .skills: return "brain.head.profile"
        case .tools: return "hammer.fill"
        case .settings: return "network"
        }
    }
}

struct ContentView: View {
    @State private var selectedTab: MainTab = .dashboard
    @Environment(GatewayService.self) private var gateway
    @Environment(AuthService.self) private var auth
    @Environment(SettingsStore.self) private var settings
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                Text("Gateway Manager")
                    .font(OC.Typography.h2)
                    .foregroundStyle(OC.Colors.textPrimary)
                
                Spacer()
                
                // Connection Status Pulse
                Circle()
                    .fill(gatewayStatusColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: gatewayStatusColor.opacity(0.3), radius: 4)
            }
            .padding(.horizontal, OC.Spacing.lg)
            .padding(.top, OC.Spacing.md)
            .padding(.bottom, OC.Spacing.sm)
            .background(OC.Colors.background.ignoresSafeArea(edges: .top))
            
            // Segmented Navigation Header (Horizontal Ribbon)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: OC.Spacing.md) {
                    ForEach(MainTab.allCases) { tab in
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
                case .voice: CallsView()
                case .monitoring: MonitoringView()
                case .logs: LogsView()
                case .cron: CronView()
                case .nodes: NodesView()
                case .devices: DevicesView()
                case .users: UsersView()
                case .permissions: PermissionsView()
                case .skills: SkillsView()
                case .tools: ToolsView()
                case .settings: ConnectionSettingsView()
                }
            }
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
