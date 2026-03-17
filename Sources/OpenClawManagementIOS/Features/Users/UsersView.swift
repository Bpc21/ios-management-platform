import SwiftUI
import OpenClawKit

@MainActor
struct UsersView: View {
    @Environment(GatewayService.self) private var gateway
    @Environment(AuthService.self) private var auth
    @State private var usersService = UsersDataService()

    @State private var platformUsers: [AppUser] = []
    @State private var allowlistData: UsersOverviewData?
    @State private var isLoading = false
    @State private var errorText: String?

    @State private var showingAddUser = false
    @State private var editingUser: AppUser?
    @State private var userToDelete: AppUser?

    @State private var newAllowlistPhone = ""
    @State private var isSavingAllowlist = false

    var body: some View {
        NavigationStack {
            ZStack {
                OC.Colors.background.ignoresSafeArea()

                if isLoading && platformUsers.isEmpty {
                    ProgressView("Loading...")
                } else {
                    ScrollView {
                        VStack(spacing: OC.Spacing.xl) {
                            if let errorText {
                                Text(errorText)
                                    .font(OC.Typography.caption)
                                    .foregroundStyle(OC.Colors.destructive)
                                    .padding(.top)
                            }

                            platformUsersSection
                            allowlistSection
                        }
                        .padding(.vertical)
                    }
                    .refreshable {
                        await loadData()
                    }
                }
            }
            .navigationTitle("Users")
            .ocNavigationBarTitleDisplayModeInline()
            .task {
                await loadData()
            }
            .sheet(isPresented: $showingAddUser) {
                AddUserSheet()
                    .onDisappear { Task { await loadData() } }
            }
            .sheet(item: $editingUser) { user in
                EditUserSheet(user: user)
                    .onDisappear { Task { await loadData() } }
            }
            .alert("Delete User?", isPresented: Binding(
                get: { userToDelete != nil },
                set: { if !$0 { userToDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let user = userToDelete {
                        performDelete(user: user)
                    }
                }
            } message: {
                if let user = userToDelete {
                    Text("Are you sure you want to delete \(user.username)? This cannot be undone.")
                }
            }
        }
    }

    private var platformUsersSection: some View {
        VStack(alignment: .leading, spacing: OC.Spacing.md) {
            HStack {
                Text("PLATFORM USERS")
                    .font(OC.Typography.caption)
                    .foregroundStyle(OC.Colors.textTertiary)
                    .kerning(1.5)
                Spacer()
                if auth.canMutate {
                    Button(action: { showingAddUser = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(OC.Colors.accent)
                    }
                }
            }

            if platformUsers.isEmpty {
                Text("No platform users found.")
                    .font(OC.Typography.bodyMedium)
                    .foregroundStyle(OC.Colors.textTertiary)
                    .padding(.vertical)
            } else {
                ForEach(platformUsers) { user in
                    PlatformUserRow(
                        user: user,
                        isMe: user.id == auth.currentUser?.id,
                        canEdit: auth.canMutate,
                        onEdit: { editingUser = user },
                        onDelete: { userToDelete = user }
                    )
                }
            }
        }
        .padding(.horizontal)
    }

    private var allowlistSection: some View {
        VStack(alignment: .leading, spacing: OC.Spacing.md) {
            Text("WHATSAPP ALLOWLIST")
                .font(OC.Typography.caption)
                .foregroundStyle(OC.Colors.textTertiary)
                .kerning(1.5)

            if auth.canMutate {
                HStack {
                    TextField("+1234567890", text: $newAllowlistPhone)
#if os(iOS)
                        .ocKeyboardTypePhonePad()
#endif
                        .textFieldStyle(.plain)
                        .padding(OC.Spacing.sm)
                        .background(OC.Colors.surfaceElevated)
                        .cornerRadius(OC.Radius.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: OC.Radius.sm)
                                .strokeBorder(OC.Colors.border)
                        )
                    
                    Button(action: addAllowlistPhone) {
                        if isSavingAllowlist {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Add")
                                .font(OC.Typography.bodyMedium)
                        }
                    }
                    .disabled(newAllowlistPhone.isEmpty || isSavingAllowlist)
                    .padding(.horizontal, OC.Spacing.md)
                    .padding(.vertical, OC.Spacing.sm)
                    .background(newAllowlistPhone.isEmpty || isSavingAllowlist ? OC.Colors.surfaceDisabled : OC.Colors.accent)
                    .foregroundStyle(newAllowlistPhone.isEmpty || isSavingAllowlist ? OC.Colors.textTertiary : .white)
                    .cornerRadius(OC.Radius.sm)
                }
            }

            if let data = allowlistData {
                let unlinked = unlinkedPhones(data: data)
                if unlinked.isEmpty {
                    Text("All allowlisted numbers are linked to users.")
                        .font(OC.Typography.bodyMedium)
                        .foregroundStyle(OC.Colors.textTertiary)
                        .padding(.vertical, OC.Spacing.sm)
                } else {
                    ForEach(unlinked, id: \.self) { phone in
                        HStack {
                            Text(phone)
                                .font(OC.Typography.bodyMedium)
                                .foregroundStyle(OC.Colors.textPrimary)
                            Spacer()
                            if auth.canMutate {
                                Button(role: .destructive, action: { removeAllowlistPhone(phone) }) {
                                    Image(systemName: "trash")
                                        .foregroundStyle(OC.Colors.destructive)
                                }
                            }
                        }
                        .padding()
                        .background(OC.Colors.surfaceElevated)
                        .cornerRadius(OC.Radius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: OC.Radius.md)
                                .strokeBorder(OC.Colors.border)
                        )
                    }
                }
            }
        }
        .padding(.horizontal)
    }


    private func loadData() async {
        guard !isLoading else { return }
        isLoading = true
        errorText = nil
        do {
            async let users = auth.allUsers()
            async let allowlist = usersService.loadOverview(gateway: gateway)
            
            let (fetchedUsers, fetchedAllowlist) = try await (users, allowlist)
            
            self.platformUsers = fetchedUsers
            self.allowlistData = fetchedAllowlist
        } catch {
            self.errorText = error.localizedDescription
        }
        isLoading = false
    }

    private func unlinkedPhones(data: UsersOverviewData) -> [String] {
        let platformPhones = Set(platformUsers.compactMap { $0.phone })
        return data.allowlist.filter { !platformPhones.contains($0) }
    }

    private func addAllowlistPhone() {
        guard let data = allowlistData else { return }
        let phone = newAllowlistPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !phone.isEmpty else { return }
        
        var updated = data.allowlist
        if !updated.contains(phone) {
            updated.append(phone)
        }
        
        saveAllowlist(updated)
    }

    private func removeAllowlistPhone(_ phone: String) {
        guard let data = allowlistData else { return }
        var updated = data.allowlist
        updated.removeAll { $0 == phone }
        saveAllowlist(updated)
    }

    private func saveAllowlist(_ updated: [String]) {
        isSavingAllowlist = true
        Task {
            do {
                try await usersService.saveAllowlist(gateway: gateway, updatedAllowlist: updated)
                newAllowlistPhone = ""
                await loadData()
            } catch {
                errorText = error.localizedDescription
            }
            isSavingAllowlist = false
        }
    }

    private func performDelete(user: AppUser) {
        Task {
            do {
                try await auth.deleteUser(user)
                await loadData()
            } catch {
                errorText = error.localizedDescription
            }
        }
    }
}

struct PlatformUserRow: View {
    let user: AppUser
    let isMe: Bool
    let canEdit: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: OC.Spacing.xs) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: OC.Spacing.sm) {
                        Text(user.displayName)
                            .font(OC.Typography.h3)
                            .foregroundStyle(OC.Colors.textPrimary)
                        
                        Text(user.role.label)
                            .font(OC.Typography.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(OC.Colors.accent.opacity(0.1))
                            .foregroundStyle(OC.Colors.accent)
                            .cornerRadius(OC.Radius.sm)
                    }
                    
                    Text(user.username)
                        .font(OC.Typography.caption)
                        .foregroundStyle(OC.Colors.textTertiary)
                }
                
                Spacer()
                
                if canEdit {
                    Menu {
                        Button(action: onEdit) {
                            Label("Edit", systemImage: "pencil")
                        }
                        if !isMe {
                            Button(role: .destructive, action: onDelete) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 20))
                            .foregroundStyle(OC.Colors.textSecondary)
                    }
                }
            }
            
            if let phone = user.phone {
                HStack(spacing: OC.Spacing.xs) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 10))
                    Text(phone)
                }
                .font(OC.Typography.caption)
                .foregroundStyle(OC.Colors.textSecondary)
                .padding(.top, 2)
            }
        }
        .padding()
        .background(OC.Colors.surfaceElevated)
        .cornerRadius(OC.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: OC.Radius.md)
                .strokeBorder(OC.Colors.border)
        )
    }
}
