import SwiftUI
import SwiftData
import OpenClawKit

@main
struct OpenClawManagementIOS: App {
    private var settingsStore = SettingsStore.shared
    @State private var gateway: GatewayService
    @State private var authService: AuthService
    
    init() {
        let container = PersistenceContainer.shared
        let auth = AuthService(modelContext: container.mainContext)
        _authService = State(wrappedValue: auth)
        
        let gw = GatewayService()
        _gateway = State(wrappedValue: gw)
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                // If not authenticated, we'd shoe Login/Onboarding. For now, we skip straight to main UI shell.
                ContentView()
            }
            .environment(settingsStore)
            .environment(gateway)
            .environment(authService)
            .preferredColorScheme(.dark) // The Executive Dashboard prefers true blacks
            .onAppear {
                Task {
                    authService.restoreSession()
                    if !settingsStore.gatewayHost.isEmpty {
                        await gateway.connect(settings: settingsStore)
                    }
                }
            }
        }
        .modelContainer(PersistenceContainer.shared)
    }
}
