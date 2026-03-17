import SwiftUI
import OpenClawKit

struct UsersView: View {
    @Environment(GatewayService.self) private var gateway
    @State private var usersService = UsersDataService()
    
    @State private var overviewData: UsersOverviewData?
    @State private var errorText: String?
    @State private var isLoading = false
    @State private var newPhoneNumber = ""
    @State private var isSaving = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: OC.Spacing.md) {
                    
                    if let errorText {
                        Text(errorText)
                            .foregroundStyle(OC.Colors.destructive)
                            .padding(.top, OC.Spacing.xl)
                    }
                    
                    if isLoading && overviewData == nil {
                        ProgressView("Loading users...")
                            .padding(.top, OC.Spacing.xxl)
                    } else if let data = overviewData {
                        
                        // Add User Section
                        VStack(alignment: .leading, spacing: OC.Spacing.sm) {
                            Text("ADD ALLOWLIST ENTRY")
                                .font(OC.Typography.caption)
                                .foregroundStyle(OC.Colors.textTertiary)
                            
                            HStack {
                                TextField("+1234567890", text: $newPhoneNumber)
#if os(iOS)
                                    .keyboardType(.phonePad)
#endif
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(OC.Spacing.sm)
                                    .background(OC.Colors.background)
                                    .cornerRadius(OC.Radius.sm)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: OC.Radius.sm)
                                            .strokeBorder(OC.Colors.border, lineWidth: 1)
                                    )
                                    .disabled(isSaving)
                                
                                Button(action: addPhoneNumber) {
                                    Text("Add")
                                        .font(OC.Typography.bodyMedium)
                                        .padding(.horizontal, OC.Spacing.md)
                                        .padding(.vertical, OC.Spacing.sm)
                                        .background(newPhoneNumber.isEmpty ? OC.Colors.surfaceDisabled : OC.Colors.accent)
                                        .foregroundStyle(newPhoneNumber.isEmpty ? OC.Colors.textTertiary : .white)
                                        .cornerRadius(OC.Radius.sm)
                                }
                                .disabled(newPhoneNumber.isEmpty || isSaving)
                            }
                        }
                        .ocCard()
                        
                        // Overview Rows
                        VStack(alignment: .leading, spacing: OC.Spacing.sm) {
                            HStack {
                                Text("WHITELISTED USERS")
                                    .font(OC.Typography.caption)
                                    .foregroundStyle(OC.Colors.textTertiary)
                                Spacer()
                                Text("\(data.allowlist.count) total")
                                    .font(OC.Typography.caption)
                                    .foregroundStyle(OC.Colors.textSecondary)
                            }
                            .padding(.horizontal, OC.Spacing.sm)
                            .padding(.top, OC.Spacing.sm)
                            
                            if data.rows.isEmpty {
                                Text("No users found in configuration.")
                                    .font(OC.Typography.bodyMedium)
                                    .foregroundStyle(OC.Colors.textTertiary)
                                    .padding(.top, OC.Spacing.lg)
                            } else {
                                ForEach(data.rows, id: \.id) { row in
                                    UserRow(row: row, onRemove: { removePhoneNumber(row.phone) })
                                }
                            }
                        }
                    }
                }
                .padding(OC.Spacing.md)
            }
            .navigationTitle("Users")
            .navigationBarHidden(true)
            .background(OC.Colors.background)
            .task {
                loadData()
            }
            .refreshable {
                loadData()
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadData() {
        guard !isLoading else { return }
        isLoading = true
        errorText = nil
        Task {
            do {
                let data = try await usersService.loadOverview(gateway: gateway)
                await MainActor.run {
                    self.overviewData = data
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorText = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func addPhoneNumber() {
        guard let data = overviewData else { return }
        let phone = newPhoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !phone.isEmpty else { return }
        
        var updated = data.allowlist
        if !updated.contains(phone) {
            updated.append(phone)
        }
        
        saveAllowlist(updated)
    }
    
    private func removePhoneNumber(_ phone: String) {
        guard let data = overviewData else { return }
        var updated = data.allowlist
        updated.removeAll { $0 == phone }
        saveAllowlist(updated)
    }
    
    private func saveAllowlist(_ updated: [String]) {
        isSaving = true
        errorText = nil
        Task {
            do {
                try await usersService.saveAllowlist(gateway: gateway, updatedAllowlist: updated)
                await MainActor.run {
                    self.newPhoneNumber = ""
                    self.isSaving = false
                }
                loadData() // Refresh cleanly
            } catch {
                await MainActor.run {
                    self.errorText = error.localizedDescription
                    self.isSaving = false
                }
            }
        }
    }
}

struct UserRow: View {
    let row: UsersOverviewRow
    let onRemove: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: OC.Spacing.sm) {
            HStack {
                Text(row.phone)
                    .font(OC.Typography.h3)
                    .foregroundStyle(OC.Colors.textPrimary)
                
                Spacer()
                
                if row.isAllowlisted {
                    Text("Allowlisted")
                        .font(OC.Typography.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(OC.Colors.success.opacity(0.1))
                        .foregroundStyle(OC.Colors.success)
                        .cornerRadius(OC.Radius.sm)
                }
                
                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(OC.Colors.destructive)
                }
                .padding(.leading, OC.Spacing.xs)
            }
            
            if !row.agents.isEmpty {
                VStack(alignment: .leading, spacing: OC.Spacing.xs) {
                    Text("Linked Agents")
                        .font(OC.Typography.caption)
                        .foregroundStyle(OC.Colors.textSecondary)
                    
                    ForEach(row.agents, id: \.id) { agent in
                        HStack {
                            Text(agent.displayName)
                                .font(OC.Typography.bodyMedium)
                                .foregroundStyle(OC.Colors.textPrimary)
                            Spacer()
                            if !agent.skills.isEmpty {
                                Text("\(agent.skills.count) skills")
                                    .font(OC.Typography.caption)
                                    .foregroundStyle(OC.Colors.textTertiary)
                            }
                        }
                    }
                }
                .padding(.top, OC.Spacing.xs)
            }
        }
        .ocCard()
        .opacity(row.isAllowlisted ? 1.0 : 0.6)
    }
}
