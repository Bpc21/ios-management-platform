import SwiftUI

struct LoginView: View {
    private enum Field: Hashable {
        case username
        case password
    }

    @Environment(AuthService.self) private var auth
    @Environment(GatewayService.self) private var gateway
    @Environment(SettingsStore.self) private var settings

    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showingConnectionSettings = false
    @FocusState private var focusedField: Field?

    var body: some View {
        ZStack {
            OC.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: OC.Spacing.xxl) {
                    Spacer(minLength: OC.Spacing.xxl)

                    // Brand mark
                    VStack(spacing: OC.Spacing.md) {
                        Image(systemName: "bolt.shield.fill")
                            .font(.system(size: 52, weight: .medium))
                            .foregroundStyle(OC.Colors.accent)

                        Text("GATEWAY MANAGER")
                            .font(OC.Typography.caption)
                            .foregroundStyle(OC.Colors.textSecondary)
                            .kerning(3.0)
                    }

                    // Login form
                    VStack(spacing: OC.Spacing.md) {
                        Text("Sign In")
                            .font(OC.Typography.h2)
                            .foregroundStyle(OC.Colors.textPrimary)

                        VStack(spacing: OC.Spacing.sm) {
                            TextField("Username", text: $username)
                                .textFieldStyle(.plain)
                                .font(OC.Typography.bodyMedium)
                                .padding(.horizontal, OC.Spacing.md)
                                .padding(.vertical, OC.Spacing.sm + 2)
                                .background(OC.Colors.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: OC.Radius.sm))
                                .overlay(
                                    RoundedRectangle(cornerRadius: OC.Radius.sm)
                                        .strokeBorder(OC.Colors.border)
                                )
                                .textContentType(.username)
                                .autocorrectionDisabled()
                                .ocTextInputAutocapitalizationNever()
                                .focused($focusedField, equals: .username)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .password }

                            SecureField("Password", text: $password)
                                .textFieldStyle(.plain)
                                .font(OC.Typography.bodyMedium)
                                .padding(.horizontal, OC.Spacing.md)
                                .padding(.vertical, OC.Spacing.sm + 2)
                                .background(OC.Colors.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: OC.Radius.sm))
                                .overlay(
                                    RoundedRectangle(cornerRadius: OC.Radius.sm)
                                        .strokeBorder(OC.Colors.border)
                                )
                                .textContentType(.password)
                                .focused($focusedField, equals: .password)
                                .submitLabel(.go)
                                .onSubmit { performLogin() }
                        }

                        if let errorMessage = auth.lastError {
                            Text(errorMessage)
                                .font(OC.Typography.caption)
                                .foregroundStyle(OC.Colors.destructive)
                                .multilineTextAlignment(.center)
                        }

                        if !gateway.connectionState.isConnected {
                            HStack(spacing: OC.Spacing.xs) {
                                Circle()
                                    .fill(OC.Colors.destructive)
                                    .frame(width: 6, height: 6)
                                Text(gateway.connectionState.label)
                                    .font(OC.Typography.caption)
                                    .foregroundStyle(OC.Colors.textTertiary)
                            }
                        }

                        Button(action: performLogin) {
                            HStack(spacing: OC.Spacing.sm) {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                        .controlSize(.small)
                                }
                                Text("Sign In")
                                    .font(OC.Typography.bodyMedium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, OC.Spacing.sm + 2)
                            .background(
                                username.trimmingCharacters(in: .whitespaces).isEmpty
                                    || password.isEmpty
                                    || isLoading
                                ? OC.Colors.surfaceDisabled
                                : OC.Colors.accent
                            )
                            .foregroundStyle(
                                username.trimmingCharacters(in: .whitespaces).isEmpty
                                    || password.isEmpty
                                    || isLoading
                                ? OC.Colors.textTertiary
                                : .white
                            )
                            .clipShape(RoundedRectangle(cornerRadius: OC.Radius.sm))
                        }
                        .disabled(
                            username.trimmingCharacters(in: .whitespaces).isEmpty
                                || password.isEmpty
                                || isLoading
                        )

                        Button("Connection Settings") {
                            showingConnectionSettings = true
                        }
                        .font(OC.Typography.caption)
                        .foregroundStyle(OC.Colors.textSecondary)
                    }
                    .padding(OC.Spacing.lg)
                    .background(OC.Colors.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: OC.Radius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: OC.Radius.md)
                            .strokeBorder(OC.Colors.border)
                    )
                    .padding(.horizontal, OC.Spacing.lg)

                    Spacer(minLength: OC.Spacing.xxl)
                }
            }
        }
        .onAppear {
            focusedField = .username
            if settings.gatewayURL == nil {
                showingConnectionSettings = true
            }
            // Attempt gateway connect if not yet connected
            if !gateway.connectionState.isConnected, settings.gatewayURL != nil {
                Task {
                    await gateway.connect(settings: settings)
                }
            }
        }
        .sheet(isPresented: $showingConnectionSettings) {
            NavigationStack {
                ConnectionSettingsView()
                    .navigationTitle("Connection Settings")
                    .ocNavigationBarTitleDisplayModeInline()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showingConnectionSettings = false
                            }
                        }
                    }
            }
        }
    }

    private func performLogin() {
        isLoading = true
        Task {
            let success = await auth.login(username: username, password: password)
            isLoading = false
            if !success {
                password = ""
            }
        }
    }
}
