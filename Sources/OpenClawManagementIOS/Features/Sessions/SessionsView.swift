import SwiftUI
import OpenClawKit
import OpenClawChatUI
import OpenClawProtocol
import OSLog

@MainActor
@Observable
final class SessionsViewModel {
    private static let logger = Logger(subsystem: "ai.openclaw.management", category: "sessions.ios")
    private let gateway: GatewayService

    var sessions: [OpenClawChatSessionEntry] = []
    var isLoading = false
    var error: String?
    var searchText = ""

    init(gateway: GatewayService) {
        self.gateway = gateway
    }

    func loadSessions() async {
        isLoading = true
        error = nil
        do {
            struct Params: Codable {
                var includeGlobal: Bool
                var includeUnknown: Bool
                var includeDerivedTitles: Bool
                var includeLastMessage: Bool
                var limit: Int?
                var search: String?
            }
            let search = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let params = Params(
                includeGlobal: true,
                includeUnknown: false,
                includeDerivedTitles: true,
                includeLastMessage: true,
                limit: 100,
                search: search.isEmpty ? nil : search)
            let json = try String(data: JSONEncoder().encode(params), encoding: .utf8)
            let data = try await gateway.requestRaw(method: "sessions.list", paramsJSON: json, timeout: 15)
            let result = try JSONDecoder().decode(OpenClawChatSessionsListResponse.self, from: data)
            sessions = result.sessions.sorted { ($0.updatedAt ?? 0) > ($1.updatedAt ?? 0) }
        } catch {
            self.error = error.localizedDescription
            Self.logger.error("Failed to load sessions: \(error.localizedDescription, privacy: .public)")
        }
        isLoading = false
    }

    func reset(_ session: OpenClawChatSessionEntry) async {
        do {
            let params = SessionsResetParams(key: session.key, reason: nil)
            let json = try String(data: JSONEncoder().encode(params), encoding: .utf8)
            _ = try await gateway.requestRaw(method: "sessions.reset", paramsJSON: json)
            await loadSessions()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func compact(_ session: OpenClawChatSessionEntry) async {
        do {
            let params = SessionsCompactParams(key: session.key, maxlines: nil)
            let json = try String(data: JSONEncoder().encode(params), encoding: .utf8)
            _ = try await gateway.requestRaw(method: "sessions.compact", paramsJSON: json)
            await loadSessions()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func delete(_ session: OpenClawChatSessionEntry) async {
        do {
            let params = SessionsDeleteParams(key: session.key, deletetranscript: true, emitlifecyclehooks: nil)
            let json = try String(data: JSONEncoder().encode(params), encoding: .utf8)
            _ = try await gateway.requestRaw(method: "sessions.delete", paramsJSON: json)
            await loadSessions()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct SessionsView: View {
    @Environment(GatewayService.self) private var gateway
    @Environment(AuthService.self) private var auth
    @State private var viewModel: SessionsViewModel?
    @State private var selectedSession: OpenClawChatSessionEntry?
    @State private var pendingDelete: OpenClawChatSessionEntry?

    var body: some View {
        NavigationStack {
            ZStack {
                OC.Colors.background.ignoresSafeArea()
                if let vm = viewModel {
                    content(vm: vm)
                } else {
                    ProgressView("Loading sessions...")
                }
            }
            .navigationTitle("Sessions")
            .ocNavigationBarTitleDisplayModeInline()
            .task {
                if viewModel == nil {
                    let vm = SessionsViewModel(gateway: gateway)
                    viewModel = vm
                    await vm.loadSessions()
                }
            }
            .alert("Delete Session?", isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    guard let vm = viewModel, let session = pendingDelete else { return }
                    Task { await vm.delete(session) }
                }
            } message: {
                Text("This will permanently remove the session transcript.")
            }
            .sheet(item: $selectedSession) { session in
                SessionDetailSheet(
                    session: session,
                    canMutate: auth.canMutate,
                    onReset: { Task { await viewModel?.reset(session) } },
                    onCompact: { Task { await viewModel?.compact(session) } },
                    onDelete: { pendingDelete = session }
                )
            }
        }
    }

    @ViewBuilder
    private func content(vm: SessionsViewModel) -> some View {
        @Bindable var vm = vm
        VStack(spacing: OC.Spacing.md) {
            HStack(spacing: OC.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(OC.Colors.textTertiary)
                TextField("Search sessions", text: $vm.searchText)
                    .textFieldStyle(.plain)
                    .submitLabel(.search)
                    .onSubmit { Task { await vm.loadSessions() } }
                    .autocorrectionDisabled()
                    .ocTextInputAutocapitalizationNever()
                Button {
                    Task { await vm.loadSessions() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .foregroundStyle(OC.Colors.textSecondary)
            }
            .padding(OC.Spacing.sm)
            .background(OC.Colors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: OC.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: OC.Radius.sm)
                    .strokeBorder(OC.Colors.border)
            )
            .padding(.horizontal, OC.Spacing.md)

            if let error = vm.error {
                Text(error)
                    .font(OC.Typography.caption)
                    .foregroundStyle(OC.Colors.destructive)
                    .padding(.horizontal, OC.Spacing.md)
            }

            if vm.isLoading {
                Spacer()
                ProgressView("Loading...")
                Spacer()
            } else if vm.sessions.isEmpty {
                Spacer()
                Text("No sessions found.")
                    .font(OC.Typography.bodyMedium)
                    .foregroundStyle(OC.Colors.textTertiary)
                Spacer()
            } else {
                List(vm.sessions, id: \.key) { session in
                    Button {
                        selectedSession = session
                    } label: {
                        SessionRow(session: session)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(OC.Colors.background)
                }
                .listStyle(.plain)
                .refreshable {
                    await vm.loadSessions()
                }
            }
        }
    }
}

private struct SessionRow: View {
    let session: OpenClawChatSessionEntry

    var body: some View {
        VStack(alignment: .leading, spacing: OC.Spacing.xs) {
            Text(session.displayName ?? session.key)
                .font(OC.Typography.bodyMedium)
                .foregroundStyle(OC.Colors.textPrimary)
                .lineLimit(1)

            HStack(spacing: OC.Spacing.xs) {
                Text(session.key)
                    .font(OC.Typography.monoSmall)
                    .foregroundStyle(OC.Colors.textTertiary)
                    .lineLimit(1)
                if let model = session.model {
                    Text("· \(model)")
                        .font(OC.Typography.caption)
                        .foregroundStyle(OC.Colors.textSecondary)
                        .lineLimit(1)
                }
            }

            HStack {
                if let updatedAt = session.updatedAt {
                    Text(Self.formatDate(updatedAt))
                        .font(OC.Typography.caption)
                        .foregroundStyle(OC.Colors.textTertiary)
                }
                Spacer()
                if let totalTokens = session.totalTokens {
                    Text("\(totalTokens) tokens")
                        .font(OC.Typography.caption)
                        .foregroundStyle(OC.Colors.textSecondary)
                }
            }
        }
        .padding(.vertical, OC.Spacing.xs)
    }

    private static func formatDate(_ value: Double) -> String {
        let date = Date(timeIntervalSince1970: value)
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

private struct SessionDetailSheet: View {
    let session: OpenClawChatSessionEntry
    let canMutate: Bool
    let onReset: () -> Void
    let onCompact: () -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: OC.Spacing.md) {
                    keyValue("Session", value: session.key)
                    keyValue("Model", value: session.model ?? "—")
                    keyValue("Kind", value: session.kind ?? "—")
                    keyValue("Surface", value: session.surface ?? "—")
                    keyValue("Input Tokens", value: session.inputTokens.map(String.init) ?? "—")
                    keyValue("Output Tokens", value: session.outputTokens.map(String.init) ?? "—")
                    keyValue("Total Tokens", value: session.totalTokens.map(String.init) ?? "—")

                    if canMutate {
                        HStack(spacing: OC.Spacing.md) {
                            Button("Reset", action: onReset)
                                .buttonStyle(.bordered)
                            Button("Compact", action: onCompact)
                                .buttonStyle(.bordered)
                            Button("Delete", action: onDelete)
                                .buttonStyle(.borderedProminent)
                                .tint(OC.Colors.destructive)
                        }
                    }
                }
                .ocCard()
                .padding(OC.Spacing.md)
            }
            .navigationTitle(session.displayName ?? "Session Details")
            .ocNavigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func keyValue(_ key: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: OC.Spacing.xs) {
            Text(key.uppercased())
                .font(OC.Typography.caption)
                .foregroundStyle(OC.Colors.textTertiary)
            Text(value)
                .font(OC.Typography.body)
                .foregroundStyle(OC.Colors.textPrimary)
        }
    }
}
