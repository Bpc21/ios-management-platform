import SwiftUI
import OpenClawKit

struct ConnectionSettingsView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(GatewayService.self) private var gateway
    
    @State private var urlString: String = ""
    @State private var tokenString: String = ""
    @State private var isConnecting = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: OC.Spacing.xl) {
                
                // Status Header
                VStack(spacing: OC.Spacing.sm) {
                    Image(systemName: gateway.connectionState.isConnected ? "link.cloud.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(gateway.connectionState.isConnected ? OC.Colors.success : OC.Colors.warning)
                    
                    Text(gateway.connectionState.isConnected ? "Connected to Gateway" : "Disconnected")
                        .font(OC.Typography.h2)
                        .foregroundStyle(OC.Colors.textPrimary)
                    
                    if gateway.connectionState.isConnected {
                        Text(settings.gatewayURL?.absoluteString ?? "")
                            .font(OC.Typography.mono)
                            .foregroundStyle(OC.Colors.textTertiary)
                    }
                }
                .padding(.top, OC.Spacing.xl)
                
                // Configuration Card
                VStack(alignment: .leading, spacing: OC.Spacing.md) {
                    Text("Gateway Configuration")
                        .font(OC.Typography.h3)
                        .foregroundStyle(OC.Colors.textSecondary)
                    
                    VStack(alignment: .leading, spacing: OC.Spacing.xs) {
                        Text("SERVER URL")
                            .font(OC.Typography.caption)
                            .foregroundStyle(OC.Colors.textTertiary)
                        
                        TextField("wss://gateway.local:8080", text: $urlString)
                            .font(OC.Typography.mono)
                            .textFieldStyle(.plain)
                            .padding(OC.Spacing.sm)
                            .background(Color.black.opacity(0.2))
                            .cornerRadius(OC.Radius.sm)
                            .overlay(RoundedRectangle(cornerRadius: OC.Radius.sm).stroke(OC.Colors.border))
                            .autocorrectionDisabled()
                    }
                    
                    VStack(alignment: .leading, spacing: OC.Spacing.xs) {
                        Text("ACCESS TOKEN")
                            .font(OC.Typography.caption)
                            .foregroundStyle(OC.Colors.textTertiary)
                        
                        SecureField("eyJhbGciOiJIUzI1NiIs...", text: $tokenString)
                            .font(OC.Typography.mono)
                            .textFieldStyle(.plain)
                            .padding(OC.Spacing.sm)
                            .background(Color.black.opacity(0.2))
                            .cornerRadius(OC.Radius.sm)
                            .overlay(RoundedRectangle(cornerRadius: OC.Radius.sm).stroke(OC.Colors.border))
                            .textContentType(.password)
                    }
                    
                    Button(action: saveAndConnect) {
                        HStack {
                            Spacer()
                            if isConnecting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(gateway.connectionState.isConnected ? "Update & Reconnect" : "Connect")
                                    .font(OC.Typography.bodyMedium)
                            }
                            Spacer()
                        }
                        .padding(OC.Spacing.md)
                        .background(OC.Colors.accent)
                        .foregroundStyle(.white)
                        .cornerRadius(OC.Radius.sm)
                    }
                    .disabled(urlString.isEmpty)
                    .padding(.top, OC.Spacing.sm)
                    
                    if gateway.connectionState.isConnected {
                        Button(action: disconnect) {
                            HStack {
                                Spacer()
                                Text("Disconnect")
                                    .font(OC.Typography.bodyMedium)
                                Spacer()
                            }
                            .padding(OC.Spacing.md)
                            .background(OC.Colors.surfaceElevated)
                            .foregroundStyle(OC.Colors.destructive)
                            .cornerRadius(OC.Radius.sm)
                            .overlay(RoundedRectangle(cornerRadius: OC.Radius.sm).stroke(OC.Colors.destructive, lineWidth: 1))
                        }
                    }
                }
                .ocCard()
                .padding(.horizontal, OC.Spacing.md)
                
            }
        }
        .onAppear {
            urlString = settings.gatewayHost
            tokenString = settings.loadToken() ?? ""
        }
    }
    
    private func saveAndConnect() {
        Task {
            isConnecting = true
            settings.gatewayHost = urlString
            settings.saveToken(tokenString)
            await gateway.connect(settings: settings)
            isConnecting = false
        }
    }
    
    private func disconnect() {
        Task {
            await gateway.disconnect()
        }
    }
}
