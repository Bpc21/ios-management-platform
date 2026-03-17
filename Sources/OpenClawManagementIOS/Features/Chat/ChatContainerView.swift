import SwiftUI
import OpenClawChatUI
import OpenClawKit

struct ChatContainerView: View {
    @Environment(GatewayService.self) private var gateway
    @State private var transport: OperatorChatTransport?
    
    var body: some View {
        NavigationStack {
            ZStack {
                OC.Colors.background.ignoresSafeArea()
                
                if let transport = transport, gateway.connectionState.isConnected {
                    OpenClawChatView(viewModel: OpenClawChatViewModel(sessionKey: "main", transport: transport))
                        .background(OC.Colors.background)
                } else {
                    VStack(spacing: OC.Spacing.md) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(OC.Colors.textTertiary)
                        
                        Text(gateway.connectionState.isConnected ? "Initializing chat..." : "Connect to gateway to chat.")
                            .font(OC.Typography.bodyMedium)
                            .foregroundStyle(OC.Colors.textSecondary)
                    }
                }
            }
            .navigationTitle("Main Chat")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task(id: gateway.connectionState.isConnected) {
            setupTransport()
        }
    }
    
    private func setupTransport() {
        guard gateway.connectionState.isConnected else {
            transport = nil
            return
        }
        // Initialize the operator transport so OpenClawKit's chat UI works natively
        self.transport = OperatorChatTransport(gateway: gateway.session)
    }
}
