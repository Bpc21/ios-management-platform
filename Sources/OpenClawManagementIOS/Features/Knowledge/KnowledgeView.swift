import SwiftUI

struct KnowledgeView: View {
    @Environment(OperationalCoreStore.self) private var core
    @State private var showingCreate = false

    var body: some View {
        NavigationStack {
            VStack(spacing: OC.Spacing.md) {
                header

                if core.knowledgeEntries.isEmpty {
                    VStack(spacing: OC.Spacing.sm) {
                        Text("No knowledge entries yet.")
                            .font(OC.Typography.bodyMedium)
                            .foregroundStyle(OC.Colors.textTertiary)
                        Text("Capture decisions, runbooks, and incident notes here.")
                            .font(OC.Typography.caption)
                            .foregroundStyle(OC.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(core.knowledgeEntries, id: \.id) { entry in
                        KnowledgeRow(entry: entry)
                            .listRowBackground(OC.Colors.background)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    core.deleteKnowledgeEntry(entry)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                    .listStyle(.plain)
                }
            }
            .padding(.top, OC.Spacing.md)
            .navigationTitle("Knowledge")
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
                CreateKnowledgeSheet()
            }
        }
    }

    private var header: some View {
        HStack(spacing: OC.Spacing.md) {
            metricCard("ENTRIES", value: "\(core.knowledgeEntries.count)")
            metricCard("TODAY", value: "\(entriesCreatedToday)")
        }
        .padding(.horizontal, OC.Spacing.md)
    }

    private var entriesCreatedToday: Int {
        let calendar = Calendar.current
        return core.knowledgeEntries.filter { calendar.isDateInToday($0.createdAt) }.count
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

private struct KnowledgeRow: View {
    let entry: KnowledgeItem

    var body: some View {
        VStack(alignment: .leading, spacing: OC.Spacing.xs) {
            Text(entry.title)
                .font(OC.Typography.bodyMedium)
                .foregroundStyle(OC.Colors.textPrimary)
                .lineLimit(1)

            Text(entry.content)
                .font(OC.Typography.caption)
                .foregroundStyle(OC.Colors.textSecondary)
                .lineLimit(3)

            HStack {
                Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(OC.Typography.caption)
                    .foregroundStyle(OC.Colors.textTertiary)
                Spacer()
                if let sourceTaskId = entry.sourceTaskId {
                    Text(sourceTaskId)
                        .font(OC.Typography.monoSmall)
                        .foregroundStyle(OC.Colors.textTertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, OC.Spacing.xs)
    }
}

private struct CreateKnowledgeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(OperationalCoreStore.self) private var core

    @State private var title = ""
    @State private var content = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Entry") {
                    TextField("Title", text: $title)
                    TextField("Content", text: $content, axis: .vertical)
                        .lineLimit(4...10)
                }
            }
            .navigationTitle("New Knowledge")
            .ocNavigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        core.createKnowledgeEntry(
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            content: content.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
