import SwiftUI
import OpenClawKit
import OpenClawProtocol

struct MonitoringView: View {
    @Environment(GatewayService.self) private var gateway
    
    // Limits event history to keep memory usage low on iOS
    private let maxEvents = 100
    
    var eventStream: [EventFrame] {
        // Safe access to the gateway snapshot's event stream
        return gateway.recentEvents.suffix(maxEvents).reversed()
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header Stats
                HStack {
                    Text("LIVE EVENT STREAM")
                        .font(OC.Typography.caption)
                        .foregroundStyle(OC.Colors.textTertiary)
                    
                    Spacer()
                    
                    if gateway.connectionState.isConnected {
                        HStack(spacing: OC.Spacing.xs) {
                            Circle()
                                .fill(OC.Colors.success)
                                .frame(width: 8, height: 8)
                            Text("STREAMING")
                                .font(OC.Typography.monoSmall)
                                .foregroundStyle(OC.Colors.success)
                        }
                    } else {
                        Text("DISCONNECTED")
                            .font(OC.Typography.monoSmall)
                            .foregroundStyle(OC.Colors.destructive)
                    }
                }
                .padding(.horizontal, OC.Spacing.md)
                .padding(.vertical, OC.Spacing.md)
                .background(OC.Colors.surfaceElevated)
                
                Divider()
                    .background(OC.Colors.border)
                
                ScrollView {
                    LazyVStack(spacing: OC.Spacing.xs) {
                        if eventStream.isEmpty {
                            Text("No events received yet.")
                                .font(OC.Typography.bodyMedium)
                                .foregroundStyle(OC.Colors.textTertiary)
                                .padding(.top, OC.Spacing.xxl)
                        } else {
                            ForEach(Array(eventStream.enumerated()), id: \.offset) { _, event in
                                EventRow(event: event)
                            }
                        }
                    }
                    .padding(OC.Spacing.sm)
                }
                .background(OC.Colors.background)
            }
            .navigationTitle("Monitoring")
            .navigationBarTitleDisplayMode(.inline)
            .background(OC.Colors.background)
        }
    }
}

struct EventRow: View {
    let event: EventFrame
    
    var body: some View {
        VStack(alignment: .leading, spacing: OC.Spacing.xs) {
            HStack {
                Text(event.event)
                    .font(OC.Typography.monoSmall)
                    .foregroundStyle(OC.Colors.textPrimary)
                
                Spacer()
                
                Text(Date(), format: .dateTime.hour().minute().second()) // Replace with actual timestamp if provided by protocol
                    .font(OC.Typography.caption)
                    .foregroundStyle(OC.Colors.textTertiary)
            }
            
            Text(formattedPayload)
                .font(OC.Typography.monoSmall)
                .foregroundStyle(OC.Colors.accent)
                .lineLimit(3)
        }
        .padding(OC.Spacing.sm)
        .background(OC.Colors.surface)
        .cornerRadius(OC.Radius.sm)
        .overlay(RoundedRectangle(cornerRadius: OC.Radius.sm).stroke(OC.Colors.border))
    }
    
    // Helper to safely format payload if present
    private var formattedPayload: String {
        guard let payload = event.payload else { return "{}" }
        let value = payload.value
        
        if let str = value as? String { return str }
        if let _ = value as? [String: Any] { return "JSON Object" }
        if let array = value as? [Any] { return "Array [\(array.count)]" }
        if let num = value as? NSNumber { return "\(num)" }
        if let bool = value as? Bool { return "\(bool)" }
        
        return String(describing: value)
    }
}
