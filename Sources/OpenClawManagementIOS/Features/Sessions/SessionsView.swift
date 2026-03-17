import SwiftUI
import OpenClawKit

struct SessionsView: View {
    @Environment(GatewayService.self) private var gateway
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: OC.Spacing.md) {
                    Text("No active sessions currently recorded.")
                        .font(OC.Typography.bodyMedium)
                        .foregroundStyle(OC.Colors.textTertiary)
                        .padding(.top, OC.Spacing.xxl)
                }
                .padding(OC.Spacing.md)
            }
            .navigationTitle("Sessions")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
