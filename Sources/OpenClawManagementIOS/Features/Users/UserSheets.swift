import SwiftUI

struct AddUserSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var auth
    
    @State private var username = ""
    @State private var displayName = ""
    @State private var password = ""
    @State private var role: AppUserRole = .basic
    @State private var phone = ""
    @State private var isSaving = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("User Information") {
                    TextField("Username", text: $username)
                        .ocTextInputAutocapitalizationNever()
                        .autocorrectionDisabled()
                    TextField("Display Name", text: $displayName)
                    SecureField("Password", text: $password)
                }

                Section("Access Control") {
                    Picker("Role", selection: $role) {
                        ForEach(AppUserRole.allCases, id: \.self) { role in
                            Text(role.label).tag(role)
                        }
                    }
                }

                Section("Communication") {
                    TextField("Phone Number", text: $phone)
#if os(iOS)
                        .ocKeyboardTypePhonePad()
#endif
                }

                if let errorText {
                    Section {
                        Text(errorText)
                            .foregroundStyle(OC.Colors.destructive)
                            .font(OC.Typography.caption)
                    }
                }
            }
            .navigationTitle("Add User")
            .ocNavigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(username.isEmpty || password.isEmpty || isSaving)
                }
            }
            .disabled(isSaving)
            .overlay {
                if isSaving {
                    ProgressView()
                        .padding()
                        .background(OC.Colors.surfaceElevated)
                        .cornerRadius(OC.Radius.md)
                }
            }
        }
    }

    private func save() {
        isSaving = true
        errorText = nil
        Task {
            do {
                _ = try await auth.createUser(
                    username: username,
                    displayName: displayName,
                    password: password,
                    role: role,
                    phone: phone.isEmpty ? nil : phone
                )
                dismiss()
            } catch {
                errorText = error.localizedDescription
                isSaving = false
            }
        }
    }
}

struct EditUserSheet: View {
    let user: AppUser
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var auth

    @State private var displayName: String
    @State private var password = ""
    @State private var role: AppUserRole
    @State private var phone: String
    @State private var isSaving = false
    @State private var errorText: String?

    init(user: AppUser) {
        self.user = user
        _displayName = State(initialValue: user.displayName)
        _role = State(initialValue: user.role)
        _phone = State(initialValue: user.phone ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("User Information") {
                    Text(user.username)
                        .foregroundStyle(OC.Colors.textTertiary)
                    TextField("Display Name", text: $displayName)
                    SecureField("New Password (optional)", text: $password)
                }

                Section("Access Control") {
                    Picker("Role", selection: $role) {
                        ForEach(AppUserRole.allCases, id: \.self) { role in
                            Text(role.label).tag(role)
                        }
                    }
                }

                Section("Communication") {
                    TextField("Phone Number", text: $phone)
#if os(iOS)
                        .ocKeyboardTypePhonePad()
#endif
                }

                if let errorText {
                    Section {
                        Text(errorText)
                            .foregroundStyle(OC.Colors.destructive)
                            .font(OC.Typography.caption)
                    }
                }
            }
            .navigationTitle("Edit User")
            .ocNavigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(isSaving)
                }
            }
            .disabled(isSaving)
            .overlay {
                if isSaving {
                    ProgressView()
                        .padding()
                        .background(OC.Colors.surfaceElevated)
                        .cornerRadius(OC.Radius.md)
                }
            }
        }
    }

    private func save() {
        isSaving = true
        errorText = nil
        Task {
            do {
                _ = try await auth.updateUser(
                    user,
                    displayName: displayName,
                    password: password.isEmpty ? nil : password,
                    role: role,
                    phone: phone
                )
                dismiss()
            } catch {
                errorText = error.localizedDescription
                isSaving = false
            }
        }
    }
}
