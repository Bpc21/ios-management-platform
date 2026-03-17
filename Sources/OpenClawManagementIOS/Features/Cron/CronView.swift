import SwiftUI
import OpenClawKit

struct CronView: View {
    @Environment(GatewayService.self) private var gateway
    @State private var cronService = CronService()

    @State private var showingCreate = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: OC.Spacing.md) {
                    if cronService.isLoading {
                        ProgressView("Loading cron jobs...")
                            .padding(.top, OC.Spacing.xxl)
                    } else if cronService.jobs.isEmpty {
                        Text("No scheduled cron jobs.")
                            .font(OC.Typography.bodyMedium)
                            .foregroundStyle(OC.Colors.textTertiary)
                            .padding(.top, OC.Spacing.xxl)
                    } else {
                        ForEach(cronService.jobs, id: \.id) { job in
                            CronJobRow(
                                job: job,
                                service: cronService,
                                onActionCompleted: { Task { await reloadJobs() } })
                        }
                    }
                }
                .padding(OC.Spacing.md)
            }
            .navigationTitle("Cron Jobs")
            .ocNavigationBarTitleDisplayModeInline()
            .background(OC.Colors.background)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(!gateway.connectionState.isConnected)
                }
            }
            .task {
                await reloadJobs()
            }
            .refreshable {
                await reloadJobs()
            }
            .sheet(isPresented: $showingCreate) {
                CronCreateSheet(
                    service: cronService,
                    gateway: gateway,
                    onCreated: {
                        showingCreate = false
                        Task { await reloadJobs() }
                    })
            }
        }
    }

    private func reloadJobs() async {
        do {
            cronService.isLoading = true
            cronService.jobs = try await cronService.loadJobs(gateway: gateway)
        } catch {
            // Keep current behavior: silently fail and preserve existing rows.
        }
        cronService.isLoading = false
    }
}

private struct CronCreateSheet: View {
    let service: CronService
    let gateway: GatewayService
    let onCreated: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var form = CronEditorForm()
    @State private var isSaving = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Job") {
                    TextField("Name", text: $form.name)
                    TextField("Description", text: $form.description, axis: .vertical)
                        .lineLimit(2...4)
                    Toggle("Enabled", isOn: $form.enabled)
                }

                Section("Target") {
                    Picker("Session target", selection: $form.sessionTarget) {
                        Text("Isolated").tag(CronSessionTarget.isolated)
                        Text("Main").tag(CronSessionTarget.main)
                    }
                    .pickerStyle(.segmented)
                    TextField("Agent ID (optional)", text: $form.agentId)
                    TextField("Session key (optional)", text: $form.sessionKey)
                }

                Section("Schedule") {
                    Picker("Kind", selection: $form.scheduleKind) {
                        ForEach(CronScheduleKind.allCases, id: \.self) { kind in
                            Text(kind.rawValue.capitalized).tag(kind)
                        }
                    }

                    switch form.scheduleKind {
                    case .every:
                        Stepper("Every \(form.everyAmount) \(form.everyUnit.rawValue)", value: $form.everyAmount, in: 1...999)
                        Picker("Unit", selection: $form.everyUnit) {
                            ForEach(CronEveryUnit.allCases, id: \.self) { unit in
                                Text(unit.rawValue.capitalized).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                    case .at:
                        DatePicker("Run at", selection: $form.atDate)
                    case .cron:
                        TextField("Cron expression", text: $form.cronExpr)
                            .font(OC.Typography.mono)
                        TextField("Timezone (optional)", text: $form.cronTimeZone)
                            .ocTextInputAutocapitalizationNever()
                    }
                }

                Section("Payload") {
                    if form.sessionTarget == .isolated {
                        Picker("Payload kind", selection: $form.payloadKind) {
                            ForEach(CronPayloadKind.allCases, id: \.self) { kind in
                                Text(kind == .agentTurn ? "Agent Turn" : "System Event").tag(kind)
                            }
                        }
                        .pickerStyle(.segmented)
                    } else {
                        Text("Main session target uses System Event payload.")
                            .font(OC.Typography.caption)
                            .foregroundStyle(OC.Colors.textTertiary)
                    }

                    TextField(
                        form.payloadKind == .systemEvent ? "System text" : "Agent message",
                        text: $form.payloadText,
                        axis: .vertical)
                    .lineLimit(3...7)
                }

                if let errorText {
                    Section {
                        Text(errorText)
                            .font(OC.Typography.caption)
                            .foregroundStyle(OC.Colors.destructive)
                    }
                }
            }
            .navigationTitle("New Cron Job")
            .ocNavigationBarTitleDisplayModeInline()
            .onChange(of: form.sessionTarget) {
                form.alignPayloadToTarget()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving..." : "Create") {
                        Task { await create() }
                    }
                    .disabled(isSaving || form.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func create() async {
        errorText = nil
        isSaving = true
        defer { isSaving = false }

        do {
            try service.validate(form)
            try await service.addJob(gateway: gateway, form: form)
            onCreated()
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

struct CronJobRow: View {
    let job: CronJobItem
    let service: CronService
    let onActionCompleted: () -> Void

    @Environment(GatewayService.self) private var gateway

    var body: some View {
        VStack(alignment: .leading, spacing: OC.Spacing.sm) {
            HStack {
                Text(job.id)
                    .font(OC.Typography.h3)
                    .foregroundStyle(OC.Colors.textPrimary)

                Spacer()

                Toggle("", isOn: Binding(
                    get: { job.enabled },
                    set: { newValue in
                        Task {
                            try? await service.setEnabled(gateway: gateway, jobId: job.id, enabled: newValue)
                            onActionCompleted()
                        }
                    }
                ))
                .labelsHidden()
            }

            HStack {
                Image(systemName: "clock")
                    .foregroundStyle(OC.Colors.textTertiary)
                Text(job.scheduleSummary)
                    .font(OC.Typography.mono)
                    .foregroundStyle(OC.Colors.textSecondary)
            }

            Text(job.name)
                .font(OC.Typography.caption)
                .foregroundStyle(OC.Colors.textTertiary)

            if let updatedAtMs = job.updatedAtMs {
                Text("Last updated: \(Date(timeIntervalSince1970: Double(updatedAtMs) / 1000.0), format: .dateTime)")
                    .font(OC.Typography.caption)
                    .foregroundStyle(OC.Colors.textTertiary)
                    .padding(.top, OC.Spacing.xs)
            }

            HStack(spacing: OC.Spacing.md) {
                Button(action: {
                    Task {
                        try? await service.remove(gateway: gateway, jobId: job.id)
                        onActionCompleted()
                    }
                }) {
                    Text("Delete")
                        .font(OC.Typography.bodyMedium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, OC.Spacing.sm)
                        .background(OC.Colors.surfaceElevated)
                        .foregroundStyle(OC.Colors.destructive)
                        .cornerRadius(OC.Radius.sm)
                }

                Button(action: {
                    Task {
                        try? await service.runNow(gateway: gateway, jobId: job.id)
                        onActionCompleted()
                    }
                }) {
                    Text("Run Now")
                        .font(OC.Typography.bodyMedium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, OC.Spacing.sm)
                        .background(OC.Colors.accent)
                        .foregroundStyle(.white)
                        .cornerRadius(OC.Radius.sm)
                }
            }
            .padding(.top, OC.Spacing.sm)
        }
        .ocCard()
    }
}
