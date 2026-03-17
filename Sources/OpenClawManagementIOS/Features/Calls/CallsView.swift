import SwiftUI
import OpenClawKit

struct CallsView: View {
    @Environment(GatewayService.self) private var gateway
    @State private var isMuted = false
    @State private var isDeafened = false
    @State private var activeCallAgent: String? = nil
    
    var body: some View {
        NavigationStack {
            VStack(spacing: OC.Spacing.xl) {
                Spacer()
                
                // Avatar / Status
                ZStack {
                    Circle()
                        .fill(OC.Colors.surfaceElevated)
                        .frame(width: 150, height: 150)
                    
                    if let _ = activeCallAgent {
                        Image(systemName: "waveform")
                            .font(.system(size: 60))
                            .foregroundStyle(OC.Colors.accent)
                    } else {
                        Image(systemName: "phone.down.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(OC.Colors.textTertiary)
                    }
                }
                
                VStack(spacing: OC.Spacing.xs) {
                    Text(activeCallAgent != nil ? "Connected to Gateway" : "Ready to Call")
                        .font(OC.Typography.h2)
                        .foregroundStyle(OC.Colors.textPrimary)
                    
                    Text("Gateway Audio Channel")
                        .font(OC.Typography.body)
                        .foregroundStyle(OC.Colors.textSecondary)
                }
                
                Spacer()
                
                // Controls
                HStack(spacing: OC.Spacing.xxl) {
                    // Mute
                    Button {
                        isMuted.toggle()
                    } label: {
                        VStack(spacing: OC.Spacing.sm) {
                            Circle()
                                .fill(isMuted ? OC.Colors.destructive.opacity(0.2) : OC.Colors.surfaceElevated)
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
                                        .foregroundStyle(isMuted ? OC.Colors.destructive : OC.Colors.textPrimary)
                                        .font(.title2)
                                )
                            Text(isMuted ? "Unmute" : "Mute")
                                .font(OC.Typography.caption)
                                .foregroundStyle(OC.Colors.textSecondary)
                        }
                    }
                    
                    // Call Action
                    Button {
                        if activeCallAgent != nil {
                            endCall()
                        } else {
                            startCall()
                        }
                    } label: {
                        VStack(spacing: OC.Spacing.sm) {
                            Circle()
                                .fill(activeCallAgent != nil ? OC.Colors.destructive : OC.Colors.success)
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: activeCallAgent != nil ? "phone.down.fill" : "phone.fill")
                                        .foregroundStyle(.white)
                                        .font(.title)
                                )
                            Text(activeCallAgent != nil ? "End Call" : "Connect")
                                .font(OC.Typography.caption)
                                .foregroundStyle(OC.Colors.textSecondary)
                        }
                    }
                    
                    // Deafen
                    Button {
                        isDeafened.toggle()
                    } label: {
                        VStack(spacing: OC.Spacing.sm) {
                            Circle()
                                .fill(isDeafened ? OC.Colors.warning.opacity(0.2) : OC.Colors.surfaceElevated)
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Image(systemName: isDeafened ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                        .foregroundStyle(isDeafened ? OC.Colors.warning : OC.Colors.textPrimary)
                                        .font(.title2)
                                )
                            Text(isDeafened ? "Undeafen" : "Deafen")
                                .font(OC.Typography.caption)
                                .foregroundStyle(OC.Colors.textSecondary)
                        }
                    }
                }
                .padding(.bottom, OC.Spacing.xxl)
            }
            .background(OC.Colors.background)
            .navigationTitle("Voice Ops")
            .navigationBarHidden(true)
        }
    }
    
    private func startCall() {
        guard gateway.connectionState.isConnected else { return }
        // In a real implementation this would trigger WebRTC / LiveKit
        withAnimation {
            activeCallAgent = "Alpha Node"
        }
    }
    
    private func endCall() {
        withAnimation {
            activeCallAgent = nil
        }
    }
}
