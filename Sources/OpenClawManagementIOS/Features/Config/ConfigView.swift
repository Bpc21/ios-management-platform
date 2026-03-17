import SwiftUI

@MainActor
struct ConfigView: View {
    @Environment(GatewayService.self) private var gateway
    @State private var service = ConfigDataService()

    @State private var rawConfigText = ""
    @State private var baseHash = ""
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var statusMessage: String?
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: OC.Spacing.md) {
                header

                if gateway.connectionState.isConnected {
                    editor
                } else {
                    disconnectedState
                }
            }
            .padding(OC.Spacing.md)
            .background(OC.Colors.background)
            .navigationTitle("Config")
            .ocNavigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await reload() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading || !gateway.connectionState.isConnected)
                }
            }
            .task(id: gateway.connectionState.isConnected) {
                if gateway.connectionState.isConnected {
                    await reload()
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: OC.Spacing.md) {
            VStack(alignment: .leading, spacing: OC.Spacing.xs) {
                Text("STATE")
                    .font(OC.Typography.caption)
                    .foregroundStyle(OC.Colors.textTertiary)
                Text(gateway.connectionState.label)
                    .font(OC.Typography.bodyMedium)
                    .foregroundStyle(gateway.connectionState.isConnected ? OC.Colors.success : OC.Colors.destructive)
                    .lineLimit(1)
            }
            .ocCard()
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: OC.Spacing.xs) {
                Text("HASH")
                    .font(OC.Typography.caption)
                    .foregroundStyle(OC.Colors.textTertiary)
                Text(baseHash.isEmpty ? "-" : baseHash)
                    .font(OC.Typography.monoSmall)
                    .foregroundStyle(OC.Colors.textPrimary)
                    .lineLimit(1)
            }
            .ocCard()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: OC.Spacing.sm) {
            if let statusMessage {
                Text(statusMessage)
                    .font(OC.Typography.caption)
                    .foregroundStyle(OC.Colors.success)
            }

            if let errorText {
                Text(errorText)
                    .font(OC.Typography.caption)
                    .foregroundStyle(OC.Colors.destructive)
            }

            TextEditor(text: $rawConfigText)
                .font(OC.Typography.monoSmall)
                .frame(minHeight: 320)
                .padding(OC.Spacing.sm)
                .background(OC.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: OC.Radius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: OC.Radius.sm)
                        .strokeBorder(OC.Colors.border)
                )

            HStack(spacing: OC.Spacing.md) {
                Button {
                    do {
                        let normalized = try ConfigDataService.normalizedRawJSON(from: rawConfigText)
                        guard let data = normalized.data(using: .utf8),
                              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                        else {
                            throw NSError(domain: "ConfigView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Config must be a JSON object"])
                        }
                        rawConfigText = ConfigDataService.prettyJSONString(from: object)
                        statusMessage = "Config was formatted."
                        errorText = nil
                    } catch {
                        errorText = error.localizedDescription
                        statusMessage = nil
                    }
                } label: {
                    Text("Format")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isLoading || isSaving || rawConfigText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Save")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(OC.Colors.accent)
                .disabled(isLoading || isSaving || rawConfigText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .ocCard()
    }

    private var disconnectedState: some View {
        VStack(spacing: OC.Spacing.sm) {
            Text("Gateway is disconnected.")
                .font(OC.Typography.bodyMedium)
                .foregroundStyle(OC.Colors.textSecondary)
            Text("Connect in Settings to view and update runtime config.")
                .font(OC.Typography.caption)
                .foregroundStyle(OC.Colors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .ocCard()
    }

    private func reload() async {
        guard gateway.connectionState.isConnected else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let snapshot = try await service.loadConfig(gateway: gateway)
            baseHash = snapshot.hash
            rawConfigText = ConfigDataService.prettyJSONString(from: snapshot.config)
            errorText = nil
            statusMessage = "Loaded gateway config."
        } catch {
            errorText = error.localizedDescription
            statusMessage = nil
        }
    }

    private func save() async {
        guard gateway.connectionState.isConnected else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let normalized = try ConfigDataService.normalizedRawJSON(from: rawConfigText)
            try await service.saveConfig(gateway: gateway, rawConfigJSON: normalized, baseHash: baseHash.isEmpty ? nil : baseHash)
            statusMessage = "Config saved successfully."
            errorText = nil
            await reload()
        } catch {
            errorText = error.localizedDescription
            statusMessage = nil
        }
    }
}
