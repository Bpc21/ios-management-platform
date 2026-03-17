import SwiftUI
import OpenClawKit

struct ConnectionSettingsView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(GatewayService.self) private var gateway

    @State private var host = ""
    @State private var port = ""
    @State private var useTLS = true
    @State private var token = ""
    @State private var autoConnect = false
    @State private var connectionMode: ConnectionMode = .local
    @State private var remoteTransport: RemoteTransport = .direct
    @State private var remoteURL = ""
    @State private var remoteSSHTarget = ""

    @State private var isConnecting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OC.Spacing.xl) {
                statusHeader
                connectionCard
                if case .error(let message) = gateway.connectionState {
                    Text(message)
                        .font(OC.Typography.caption)
                        .foregroundStyle(OC.Colors.destructive)
                        .padding(.horizontal, OC.Spacing.md)
                }
            }
            .padding(.vertical, OC.Spacing.lg)
        }
        .onAppear(perform: loadFromSettings)
    }

    private var statusHeader: some View {
        VStack(spacing: OC.Spacing.sm) {
            Image(systemName: gateway.connectionState.isConnected ? "link.badge.plus" : "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(gateway.connectionState.isConnected ? OC.Colors.success : OC.Colors.warning)

            Text(gateway.connectionState.isConnected ? "Connected" : gateway.connectionState.label)
                .font(OC.Typography.h2)
                .foregroundStyle(OC.Colors.textPrimary)

            if let gatewayURL = settings.gatewayURL?.absoluteString {
                Text(gatewayURL)
                    .font(OC.Typography.monoSmall)
                    .foregroundStyle(OC.Colors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: OC.Spacing.md) {
            Text("Connection")
                .font(OC.Typography.h3)
                .foregroundStyle(OC.Colors.textPrimary)

            Picker("Mode", selection: $connectionMode) {
                Text("Local").tag(ConnectionMode.local)
                Text("Remote").tag(ConnectionMode.remote)
            }
            .pickerStyle(.segmented)

            if connectionMode == .remote {
                Picker("Transport", selection: $remoteTransport) {
                    Text("Direct").tag(RemoteTransport.direct)
                    Text("SSH Tunnel").tag(RemoteTransport.sshTunnel)
                }
                .pickerStyle(.segmented)

                field("Gateway URL", text: $remoteURL, placeholder: "wss://gateway.tail.ts.net")

                if remoteTransport == .sshTunnel {
                    field("SSH Target", text: $remoteSSHTarget, placeholder: "user@gateway.tail.ts.net")
                }
            } else {
                field("Host", text: $host, placeholder: "192.168.1.100")

                HStack(spacing: OC.Spacing.md) {
                    field("Port", text: $port, placeholder: "443")
                        .frame(width: 130)

                    Toggle(isOn: $useTLS) {
                        Text("Use TLS")
                            .font(OC.Typography.body)
                            .foregroundStyle(OC.Colors.textSecondary)
                    }
                    .toggleStyle(.switch)
                }
            }

            secureField("Gateway Token", text: $token, placeholder: "Gateway authentication token")

            Toggle(isOn: $autoConnect) {
                Text("Auto-connect on launch")
                    .font(OC.Typography.body)
                    .foregroundStyle(OC.Colors.textSecondary)
            }
            .toggleStyle(.switch)

            if let validationMessage = validationMessage {
                Text(validationMessage)
                    .font(OC.Typography.caption)
                    .foregroundStyle(OC.Colors.warning)
            }

            HStack(spacing: OC.Spacing.md) {
                Button("Save") {
                    saveSettings()
                }
                .buttonStyle(.bordered)

                Button(gateway.connectionState.isConnected ? "Update & Reconnect" : "Connect") {
                    connect()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canConnect || isConnecting)

                if gateway.connectionState.isConnected {
                    Button("Disconnect") {
                        Task { await gateway.disconnect() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(OC.Colors.destructive)
                } else if case .error = gateway.connectionState {
                    Button("Clear Error") {
                        gateway.clearError()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .ocCard()
        .padding(.horizontal, OC.Spacing.md)
    }

    private var canConnect: Bool {
        validationMessage == nil
    }

    private var validationMessage: String? {
        switch connectionMode {
        case .remote:
            let normalized = SettingsStore.normalizedRemoteURL(remoteURL)
            if normalized.isEmpty {
                return "Invalid gateway URL. Set a remote URL like `wss://your-gateway.example.com`."
            }
            if SettingsStore.validWebSocketURL(normalized) == nil {
                return "Invalid gateway URL. Expected a full websocket URL using `ws://` or `wss://`."
            }
            return nil
        case .local:
            let normalizedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalizedHost.isEmpty {
                return "Invalid gateway URL. Local mode requires a gateway host."
            }
            guard let portValue = Int(port), (1...65535).contains(portValue) else {
                return "Invalid local port. Enter a number between 1 and 65535."
            }
            let scheme = useTLS ? "wss" : "ws"
            let raw = "\(scheme)://\(normalizedHost):\(portValue)"
            if SettingsStore.validWebSocketURL(raw) == nil {
                return "Invalid local gateway URL derived from host and port."
            }
            return nil
        }
    }

    private func loadFromSettings() {
        host = settings.gatewayHost
        port = "\(settings.gatewayPort)"
        useTLS = settings.gatewayUseTLS
        token = settings.loadToken() ?? ""
        autoConnect = settings.autoConnect
        connectionMode = settings.connectionMode
        remoteTransport = settings.remoteTransport
        remoteURL = settings.remoteURL
        remoteSSHTarget = settings.remoteSSHTarget
    }

    private func saveSettings() {
        settings.connectionMode = connectionMode
        settings.remoteTransport = remoteTransport
        settings.remoteURL = remoteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.remoteSSHTarget = remoteSSHTarget.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.gatewayHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if let portValue = Int(port), (1...65535).contains(portValue) {
            settings.gatewayPort = portValue
        }
        settings.gatewayUseTLS = useTLS
        settings.autoConnect = autoConnect
        settings.saveToken(token.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func connect() {
        Task {
            isConnecting = true
            saveSettings()
            await gateway.connect(settings: settings)
            isConnecting = false
        }
    }

    @ViewBuilder
    private func field(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: OC.Spacing.xs) {
            Text(label.uppercased())
                .font(OC.Typography.caption)
                .foregroundStyle(OC.Colors.textTertiary)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(OC.Typography.monoSmall)
                .padding(OC.Spacing.sm)
                .background(OC.Colors.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: OC.Radius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: OC.Radius.sm)
                        .strokeBorder(OC.Colors.border)
                )
                .autocorrectionDisabled()
                .ocTextInputAutocapitalizationNever()
        }
    }

    @ViewBuilder
    private func secureField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: OC.Spacing.xs) {
            Text(label.uppercased())
                .font(OC.Typography.caption)
                .foregroundStyle(OC.Colors.textTertiary)
            SecureField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(OC.Typography.monoSmall)
                .padding(OC.Spacing.sm)
                .background(OC.Colors.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: OC.Radius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: OC.Radius.sm)
                        .strokeBorder(OC.Colors.border)
                )
                .textContentType(.password)
        }
    }
}
