import SwiftUI
import OpenClawKit

struct DevicesView: View {
    @Environment(GatewayService.self) private var gateway
    @State private var nodesService = NodesDevicesService()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: OC.Spacing.md) {
                    if nodesService.isLoading {
                        ProgressView("Loading devices...")
                            .padding(.top, OC.Spacing.xxl)
                    } else if nodesService.devices.isEmpty {
                        Text("No registered devices.")
                            .font(OC.Typography.bodyMedium)
                            .foregroundStyle(OC.Colors.textTertiary)
                            .padding(.top, OC.Spacing.xxl)
                    } else {
                        ForEach(nodesService.devices, id: \.id) { device in
                            DeviceRow(device: device, service: nodesService)
                        }
                    }
                }
                .padding(OC.Spacing.md)
            }
            .navigationTitle("Devices")
            .navigationBarTitleDisplayMode(.inline)
            .background(OC.Colors.background)
            .task {
                do {
                    nodesService.isLoading = true
                    let snapshot = try await nodesService.loadDevices(gateway: gateway)
                    nodesService.devices = snapshot.pairedDevices
                } catch {}
                nodesService.isLoading = false
            }
            .refreshable {
                do {
                    nodesService.isLoading = true
                    let snapshot = try await nodesService.loadDevices(gateway: gateway)
                    nodesService.devices = snapshot.pairedDevices
                } catch {}
                nodesService.isLoading = false
            }
        }
    }
}

struct DeviceRow: View {
    let device: DeviceSummaryItem
    let service: NodesDevicesService
    @Environment(GatewayService.self) private var gateway
    @State private var isRevokeHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: OC.Spacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: OC.Spacing.xs) {
                    Text(device.displayName)
                        .font(OC.Typography.h3)
                        .foregroundStyle(OC.Colors.textPrimary)
                    
                    Text(device.id)
                        .font(OC.Typography.monoSmall)
                        .foregroundStyle(OC.Colors.textTertiary)
                }
                Spacer()
                
                Button(role: .destructive) {
                    Task { try? await service.removeDevice(gateway: gateway, deviceId: device.id) }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(OC.Colors.destructive)
                        .font(.system(size: 20))
                }
            }
            
            HStack {
                Text(device.platform)
                    .font(OC.Typography.caption)
                    .foregroundStyle(OC.Colors.textSecondary)
                
                Spacer()
                
                Text(device.clientId)
                    .font(OC.Typography.caption)
                    .foregroundStyle(OC.Colors.textTertiary)
            }
            .padding(.top, OC.Spacing.xs)
        }
        .ocCard()
    }
}
