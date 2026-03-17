import SwiftUI
import OpenClawKit

@main
struct OpenClawManagementIOS: App {
    @State private var settingsStore = SettingsStore()
    @State private var gateway: GatewayService
    @State private var authService: AuthService
    @State private var operationalCoreStore: OperationalCoreStore

    init() {
        let settings = SettingsStore()
        let gw = GatewayService()
        let auth = AuthService(gateway: gw, settings: settings)
        let coreStore = OperationalCoreStore()
        _settingsStore = State(initialValue: settings)
        _gateway = State(wrappedValue: gw)
        _authService = State(wrappedValue: auth)
        _operationalCoreStore = State(initialValue: coreStore)
    }

    var body: some Scene {
        WindowGroup {
            authGatedContent
                .environment(settingsStore)
                .environment(gateway)
                .environment(authService)
                .environment(operationalCoreStore)
                .preferredColorScheme(settingsStore.isDarkMode ? .dark : .light)
                .task {
                    if settingsStore.autoConnect, settingsStore.gatewayURL != nil {
                        await gateway.connect(settings: settingsStore)
                    }
                    await authService.restoreSession()
                }
        }
    }

    @ViewBuilder
    private var authGatedContent: some View {
        if authService.isAuthenticated {
            ContentView()
        } else {
            LoginView()
        }
    }
}
