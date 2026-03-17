import SwiftUI

struct WorkflowsView: View {
    @Environment(OperationalCoreStore.self) private var core
    @State private var showingCreate = false

    var body: some View {
        NavigationStack {
            VStack(spacing: OC.Spacing.md) {
                header

                if core.workflows.isEmpty {
                    VStack(spacing: OC.Spacing.sm) {
                        Text("No workflows yet.")
                            .font(OC.Typography.bodyMedium)
                            .foregroundStyle(OC.Colors.textTertiary)
                        Text("Create one to define repeatable execution stages.")
                            .font(OC.Typography.caption)
                            .foregroundStyle(OC.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(core.workflows, id: \.id) { workflow in
                        WorkflowRow(workflow: workflow)
                            .listRowBackground(OC.Colors.background)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    core.deleteWorkflow(workflow)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    core.toggleWorkflow(workflow)
                                } label: {
                                    Label(workflow.isActive ? "Disable" : "Enable", systemImage: workflow.isActive ? "pause.circle" : "play.circle")
                                }
                                .tint(OC.Colors.accent)
                            }
                    }
                    .listStyle(.plain)
                }
            }
            .padding(.top, OC.Spacing.md)
            .navigationTitle("Workflows")
            .ocNavigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreate) {
                CreateWorkflowSheet()
            }
        }
    }

    private var header: some View {
        HStack(spacing: OC.Spacing.md) {
            metricCard("TOTAL", value: "\(core.workflows.count)")
            metricCard("ACTIVE", value: "\(core.workflows.filter(\.isActive).count)")
            metricCard("STAGES", value: "\(core.workflows.map(\.stages.count).reduce(0, +))")
        }
        .padding(.horizontal, OC.Spacing.md)
    }

    @ViewBuilder
    private func metricCard(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: OC.Spacing.xs) {
            Text(title)
                .font(OC.Typography.caption)
                .foregroundStyle(OC.Colors.textTertiary)
            Text(value)
                .font(OC.Typography.h2)
                .foregroundStyle(OC.Colors.textPrimary)
        }
        .ocCard()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WorkflowRow: View {
    let workflow: WorkflowItem

    var body: some View {
        VStack(alignment: .leading, spacing: OC.Spacing.xs) {
            HStack {
                Text(workflow.name)
                    .font(OC.Typography.bodyMedium)
                    .foregroundStyle(OC.Colors.textPrimary)
                Spacer()
                Text(workflow.isActive ? "ACTIVE" : "DISABLED")
                    .font(OC.Typography.caption)
                    .foregroundStyle(workflow.isActive ? OC.Colors.success : OC.Colors.textTertiary)
            }

            if !workflow.descriptionText.isEmpty {
                Text(workflow.descriptionText)
                    .font(OC.Typography.caption)
                    .foregroundStyle(OC.Colors.textSecondary)
                    .lineLimit(2)
            }

            Text(stagesSummary)
                .font(OC.Typography.caption)
                .foregroundStyle(OC.Colors.textTertiary)
                .lineLimit(1)
        }
        .padding(.vertical, OC.Spacing.xs)
    }

    private var stagesSummary: String {
        let names = workflow.stages.sorted { $0.orderIndex < $1.orderIndex }.map(\.name)
        if names.isEmpty {
            return "No stages"
        }
        return names.joined(separator: " | ")
    }
}

private struct CreateWorkflowSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(OperationalCoreStore.self) private var core

    @State private var name = ""
    @State private var descriptionText = ""
    @State private var stagesText = "Plan, Build, Review"

    var body: some View {
        NavigationStack {
            Form {
                Section("Workflow") {
                    TextField("Name", text: $name)
                    TextField("Description", text: $descriptionText, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Stages") {
                    TextField("Comma-separated stage names", text: $stagesText, axis: .vertical)
                        .lineLimit(2...4)
                    Text("Example: Plan, Build, QA, Deploy")
                        .font(OC.Typography.caption)
                        .foregroundStyle(OC.Colors.textTertiary)
                }
            }
            .navigationTitle("New Workflow")
            .ocNavigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        core.createWorkflow(name: normalizedName, descriptionText: normalizedDescription, stages: parsedStages)
                        dismiss()
                    }
                    .disabled(normalizedName.isEmpty || parsedStages.isEmpty)
                }
            }
        }
    }

    private var normalizedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedDescription: String {
        descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedStages: [WorkflowStageItem] {
        stagesText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .enumerated()
            .map { index, item in
                WorkflowStageItem(
                    id: UUID().uuidString,
                    name: item,
                    role: index == 0 ? "owner" : "operator",
                    orderIndex: index)
            }
    }
}
