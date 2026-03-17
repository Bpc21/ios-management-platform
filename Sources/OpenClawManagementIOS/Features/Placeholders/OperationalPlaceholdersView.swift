import SwiftUI

private struct OperationalPlaceholderView: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        ScrollView {
            VStack(spacing: OC.Spacing.lg) {
                VStack(spacing: OC.Spacing.sm) {
                    Image(systemName: icon)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(OC.Colors.accent)
                    Text(title)
                        .font(OC.Typography.h2)
                        .foregroundStyle(OC.Colors.textPrimary)
                }

                Text(subtitle)
                    .font(OC.Typography.body)
                    .foregroundStyle(OC.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, OC.Spacing.md)
            }
            .ocCard()
            .padding(OC.Spacing.md)
        }
    }
}

struct TasksView: View {
    var body: some View {
        OperationalPlaceholderView(
            title: "Tasks",
            subtitle: "Tasks is now available in iOS navigation. Backend parity is queued for the next pass.",
            icon: "checklist")
    }
}

struct AgentActivityView: View {
    var body: some View {
        OperationalPlaceholderView(
            title: "Agent Activity",
            subtitle: "Agent Activity is now available in iOS navigation. Detailed activity flows are queued for the next pass.",
            icon: "chart.bar.xaxis")
    }
}

struct WorkflowsView: View {
    var body: some View {
        OperationalPlaceholderView(
            title: "Workflows",
            subtitle: "Workflows is now available in iOS navigation. Full workflow execution controls are queued for the next pass.",
            icon: "arrow.triangle.branch")
    }
}

struct ConfigView: View {
    var body: some View {
        OperationalPlaceholderView(
            title: "Config",
            subtitle: "Config is now available in iOS navigation. Full configuration management parity is queued for the next pass.",
            icon: "doc.badge.gearshape")
    }
}

struct KnowledgeView: View {
    var body: some View {
        OperationalPlaceholderView(
            title: "Knowledge",
            subtitle: "Knowledge is now available in iOS navigation. Knowledge operations parity is queued for the next pass.",
            icon: "brain")
    }
}
