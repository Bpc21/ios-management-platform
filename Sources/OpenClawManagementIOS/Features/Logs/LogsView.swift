import SwiftUI
import OpenClawKit

struct LogsView: View {
    @Environment(GatewayService.self) private var gateway
    @State private var logs: String = ""
    @State private var isTailing = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("SYSTEM LOGS")
                        .font(OC.Typography.caption)
                        .foregroundStyle(OC.Colors.textTertiary)
                    
                    Spacer()
                    
                    ProgressView()
                        .opacity(isTailing ? 1.0 : 0.0)
                        
                    Button(isTailing ? "Stop Tail" : "Start Tail") {
                        isTailing.toggle()
                        if isTailing { tailLogs() }
                    }
                    .font(OC.Typography.caption)
                    .foregroundStyle(isTailing ? OC.Colors.destructive : OC.Colors.accent)
                    .disabled(!gateway.connectionState.isConnected)
                }
                .padding(.horizontal, OC.Spacing.md)
                .padding(.vertical, OC.Spacing.md)
                .background(OC.Colors.surfaceElevated)
                
                Divider()
                    .background(OC.Colors.border)
                
                ScrollView {
                    Text(logs.isEmpty ? (isTailing ? "Waiting for logs..." : "Tap 'Start Tail' to stream logs.") : logs)
                        .font(OC.Typography.monoSmall)
                        .foregroundStyle(OC.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(OC.Spacing.md)
                }
                .background(OC.Colors.surface) // Slight offset from pure black
            }
            .navigationTitle("Logs")
            .ocNavigationBarTitleDisplayModeInline()
            .background(OC.Colors.background)
            .onDisappear {
                isTailing = false
            }
        }
    }
    
    private func tailLogs() {
        Task {
            logs = ""
            // Mock implementation.
            // Under normal circumstances, we'd subscribe to `gateway.requestRaw(method: "logs.tail")`
            // and process the HTTP stream or WebRTC stream.
            let dummyLogs = [
                "[INFO] Gateway started on port 8080",
                "[INFO] Loading configuration from disk...",
                "[WARN] Skipping missing SSL certificate",
                "[INFO] Agents initialized (12 loaded)"
            ]
            for log in dummyLogs {
                guard isTailing else { break }
                logs += log + "\n"
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }
}
