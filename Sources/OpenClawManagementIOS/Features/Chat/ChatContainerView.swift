import SwiftUI
import OpenClawChatUI
import OpenClawKit
import OpenClawProtocol

struct ChatContainerView: View {
    @Environment(GatewayService.self) private var gateway
    @Environment(AuthService.self) private var auth

    @State private var transport: OperatorChatTransport?
    @State private var chatViewModel: OpenClawChatViewModel?
    @State private var selectedAgentId = ""

    var body: some View {
        NavigationStack {
            ZStack {
                OC.Colors.background.ignoresSafeArea()

                if gateway.connectionState.isConnected {
                    VStack(spacing: OC.Spacing.md) {
                        if !visibleAgents.isEmpty {
                            HStack(spacing: OC.Spacing.sm) {
                                Image(systemName: "person.crop.circle")
                                    .foregroundStyle(OC.Colors.textSecondary)
                                Picker("Agent", selection: $selectedAgentId) {
                                    ForEach(visibleAgents, id: \.id) { agent in
                                        Text(agent.name ?? agent.id).tag(agent.id)
                                    }
                                }
                            }
                            .padding(OC.Spacing.sm)
                            .background(OC.Colors.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: OC.Radius.sm))
                            .overlay(
                                RoundedRectangle(cornerRadius: OC.Radius.sm)
                                    .strokeBorder(OC.Colors.border)
                            )
                            .padding(.horizontal, OC.Spacing.md)
                        }

                        if let vm = chatViewModel {
                            OpenClawChatView(
                                viewModel: vm,
                                showsSessionSwitcher: false,
                                style: .standard,
                                composerPlaceholder: "Message your agent")
                            .background(OC.Colors.background)
                        } else {
                            VStack(spacing: OC.Spacing.md) {
                                ProgressView("Initializing chat...")
                                    .font(OC.Typography.bodyMedium)
                                    .foregroundStyle(OC.Colors.textSecondary)
                            }
                        }
                    }
                } else {
                    VStack(spacing: OC.Spacing.md) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(OC.Colors.textTertiary)

                        Text("Connect to gateway to chat.")
                            .font(OC.Typography.bodyMedium)
                            .foregroundStyle(OC.Colors.textSecondary)
                    }
                }
            }
            .navigationTitle("Chat")
            .ocNavigationBarTitleDisplayModeInline()
        }
        .task(id: gateway.connectionState.isConnected) {
            await setupChat()
        }
        .onChange(of: selectedAgentId) {
            rebuildChatViewModel()
        }
        .onChange(of: gateway.agents.count) {
            applyDefaultSelectionIfNeeded()
        }
    }

    private var visibleAgents: [AgentSummary] {
        ChatAgentAccess.visibleAgents(gateway.agents, for: auth.currentUser)
    }

    private func setupChat() async {
        guard gateway.connectionState.isConnected else {
            transport = nil
            chatViewModel = nil
            selectedAgentId = ""
            return
        }

        await gateway.refreshAgents()
        applyDefaultSelectionIfNeeded()

        if transport == nil {
            transport = OperatorChatTransport(gateway: gateway.session)
        }
        rebuildChatViewModel()
    }

    private func applyDefaultSelectionIfNeeded() {
        let validIds = Set(visibleAgents.map(\.id))
        guard !validIds.isEmpty else {
            selectedAgentId = ""
            return
        }

        if selectedAgentId.isEmpty || !validIds.contains(selectedAgentId) {
            selectedAgentId = visibleAgents.first?.id ?? ""
        }
    }

    private func rebuildChatViewModel() {
        guard gateway.connectionState.isConnected, let transport else {
            chatViewModel = nil
            return
        }

        let sessionKey = ChatAgentAccess.sessionKey(for: selectedAgentId)
        chatViewModel = OpenClawChatViewModel(sessionKey: sessionKey, transport: transport)
    }
}
