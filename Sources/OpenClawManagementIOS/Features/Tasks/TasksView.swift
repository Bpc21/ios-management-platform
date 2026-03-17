import SwiftUI
import OpenClawProtocol

struct TasksView: View {
    @Environment(OperationalCoreStore.self) private var core
    @Environment(GatewayService.self) private var gateway

    @State private var selectedStatus: TaskStatus = .inbox
    @State private var showingCreate = false

    var body: some View {
        NavigationStack {
            VStack(spacing: OC.Spacing.md) {
                header
                statusPicker
                taskList
            }
            .padding(.top, OC.Spacing.md)
            .navigationTitle("Tasks")
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
                CreateTaskSheet()
            }
            .task(id: gateway.connectionState.isConnected) {
                guard gateway.connectionState.isConnected else { return }
                await gateway.refreshAgents()
            }
        }
    }

    private var header: some View {
        HStack(spacing: OC.Spacing.md) {
            metricCard("TOTAL", value: "\(core.tasks.count)")
            metricCard("ACTIVE", value: "\(core.tasks.filter { $0.status != .done }.count)")
            metricCard("DONE", value: "\(core.tasks.filter { $0.status == .done }.count)")
        }
        .padding(.horizontal, OC.Spacing.md)
    }

    private var statusPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: OC.Spacing.sm) {
                ForEach(TaskStatus.allCases, id: \.self) { status in
                    Button {
                        selectedStatus = status
                    } label: {
                        Text(status.label)
                            .font(OC.Typography.caption)
                            .foregroundStyle(selectedStatus == status ? OC.Colors.background : OC.Colors.textSecondary)
                            .padding(.horizontal, OC.Spacing.md)
                            .padding(.vertical, OC.Spacing.xs)
                            .background(selectedStatus == status ? OC.Colors.accent : OC.Colors.surfaceElevated)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, OC.Spacing.md)
        }
    }

    private var taskList: some View {
        let items = core.tasks(in: selectedStatus)
        return Group {
            if items.isEmpty {
                VStack(spacing: OC.Spacing.sm) {
                    Text("No tasks in \(selectedStatus.label).")
                        .font(OC.Typography.body)
                        .foregroundStyle(OC.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(items, id: \.id) { task in
                    TaskRow(task: task)
                        .listRowBackground(OC.Colors.background)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                core.deleteTask(task)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            if let next = nextStatus(after: task.status) {
                                Button {
                                    core.moveTask(task, to: next)
                                } label: {
                                    Label(next.label, systemImage: "arrow.right.circle")
                                }
                                .tint(OC.Colors.accent)
                            }
                        }
                }
                .listStyle(.plain)
            }
        }
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

    private func nextStatus(after current: TaskStatus) -> TaskStatus? {
        guard let index = TaskStatus.allCases.firstIndex(of: current),
              index + 1 < TaskStatus.allCases.count
        else {
            return nil
        }
        return TaskStatus.allCases[index + 1]
    }
}

private struct TaskRow: View {
    @Environment(GatewayService.self) private var gateway

    let task: TaskItem

    var body: some View {
        VStack(alignment: .leading, spacing: OC.Spacing.xs) {
            HStack {
                Text(task.title)
                    .font(OC.Typography.bodyMedium)
                    .foregroundStyle(OC.Colors.textPrimary)
                    .lineLimit(1)
                Spacer()
                Text(task.priority.label)
                    .font(OC.Typography.caption)
                    .foregroundStyle(priorityColor)
            }

            if !task.descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(task.descriptionText)
                    .font(OC.Typography.caption)
                    .foregroundStyle(OC.Colors.textSecondary)
                    .lineLimit(2)
            }

            HStack {
                Text(task.status.label)
                    .font(OC.Typography.caption)
                    .foregroundStyle(OC.Colors.textTertiary)
                Spacer()
                if let assignedAgentId = task.assignedAgentId {
                    Text(agentName(for: assignedAgentId))
                        .font(OC.Typography.caption)
                        .foregroundStyle(OC.Colors.textSecondary)
                }
            }
        }
        .padding(.vertical, OC.Spacing.xs)
    }

    private var priorityColor: Color {
        switch task.priority {
        case .low: return OC.Colors.textTertiary
        case .medium: return OC.Colors.textSecondary
        case .high: return OC.Colors.warning
        case .critical: return OC.Colors.destructive
        }
    }

    private func agentName(for id: String) -> String {
        if let agent = gateway.agents.first(where: { $0.id == id }) {
            return agent.name ?? agent.id
        }
        return id
    }
}

private struct CreateTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(OperationalCoreStore.self) private var core
    @Environment(GatewayService.self) private var gateway

    @State private var title = ""
    @State private var descriptionText = ""
    @State private var priority: TaskPriority = .medium
    @State private var status: TaskStatus = .inbox
    @State private var assignedAgentId = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $descriptionText, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Assignment") {
                    Picker("Priority", selection: $priority) {
                        ForEach(TaskPriority.allCases, id: \.self) { item in
                            Text(item.label).tag(item)
                        }
                    }
                    Picker("Status", selection: $status) {
                        ForEach(TaskStatus.allCases, id: \.self) { item in
                            Text(item.label).tag(item)
                        }
                    }
                    Picker("Agent", selection: $assignedAgentId) {
                        Text("Unassigned").tag("")
                        ForEach(gateway.agents, id: \.id) { agent in
                            Text(agent.name ?? agent.id).tag(agent.id)
                        }
                    }
                }
            }
            .navigationTitle("New Task")
            .ocNavigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        core.createTask(
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            descriptionText: descriptionText.trimmingCharacters(in: .whitespacesAndNewlines),
                            priority: priority,
                            status: status,
                            assignedAgentId: assignedAgentId.isEmpty ? nil : assignedAgentId)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
