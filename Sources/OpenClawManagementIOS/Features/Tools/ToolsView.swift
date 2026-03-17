import SwiftUI
import OpenClawKit

struct ToolsView: View {
    @Environment(GatewayService.self) private var gateway
    @State private var toolsService = ToolsCatalogService()
    
    @State private var catalogData: ToolsCatalogViewData? = nil
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var searchText: String = ""
    
    var filteredGroups: [ToolCatalogGroupItem] {
        guard let data = catalogData else { return [] }
        if searchText.isEmpty {
            return data.groups
        }
        
        return data.groups.compactMap { group in
            let matchingTools = group.tools.filter { tool in
                tool.label.localizedCaseInsensitiveContains(searchText) ||
                tool.description.localizedCaseInsensitiveContains(searchText)
            }
            if matchingTools.isEmpty { return nil }
            return ToolCatalogGroupItem(
                id: group.id,
                label: group.label,
                source: group.source,
                tools: matchingTools
            )
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(OC.Colors.textTertiary)
                    TextField("Search tools...", text: $searchText)
                        .font(OC.Typography.bodyMedium)
                        .foregroundStyle(OC.Colors.textPrimary)
                        .autocorrectionDisabled()
                }
                .padding(OC.Spacing.sm)
                .background(OC.Colors.surfaceElevated)
                .cornerRadius(OC.Radius.sm)
                .padding(.horizontal, OC.Spacing.md)
                .padding(.vertical, OC.Spacing.md)
                
                Divider()
                    .background(OC.Colors.border)
                
                ScrollView {
                    VStack(spacing: OC.Spacing.md) {
                        
                        if let errorText {
                            Text(errorText)
                                .foregroundStyle(OC.Colors.destructive)
                                .padding(.top, OC.Spacing.xl)
                        }
                        
                        if isLoading && catalogData == nil {
                            ProgressView("Loading tools catalog...")
                                .padding(.top, OC.Spacing.xxl)
                        } else if let _ = catalogData, filteredGroups.isEmpty {
                            Text("No tools found.")
                                .font(OC.Typography.bodyMedium)
                                .foregroundStyle(OC.Colors.textTertiary)
                                .padding(.top, OC.Spacing.xxl)
                        } else {
                            ForEach(filteredGroups, id: \.id) { group in
                                VStack(alignment: .leading, spacing: OC.Spacing.sm) {
                                    Text(group.label.uppercased())
                                        .font(OC.Typography.caption)
                                        .foregroundStyle(OC.Colors.textTertiary)
                                        .padding(.horizontal, OC.Spacing.xs)
                                    
                                    ForEach(group.tools, id: \.id) { tool in
                                        ToolRow(tool: tool, source: group.source)
                                    }
                                }
                                .padding(.bottom, OC.Spacing.sm)
                            }
                        }
                    }
                    .padding(OC.Spacing.md)
                }
                .background(OC.Colors.background)
            }
            .navigationTitle("Tools")
            .navigationBarTitleDisplayMode(.inline)
            .background(OC.Colors.background)
            .task {
                loadData()
            }
            .refreshable {
                loadData()
            }
        }
    }
    
    private func loadData() {
        guard !isLoading else { return }
        isLoading = true
        errorText = nil
        Task {
            do {
                let data = try await toolsService.loadCatalog(gateway: gateway)
                await MainActor.run {
                    self.catalogData = data
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
}

struct ToolRow: View {
    let tool: ToolCatalogEntryItem
    let source: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: OC.Spacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: OC.Spacing.xs) {
                    Text(tool.label)
                        .font(OC.Typography.h3)
                        .foregroundStyle(OC.Colors.textPrimary)
                    
                    Text(tool.id)
                        .font(OC.Typography.monoSmall)
                        .foregroundStyle(OC.Colors.textTertiary)
                }
                
                Spacer()
                
                Text(tool.source)
                    .font(OC.Typography.caption)
                    .foregroundStyle(OC.Colors.accent)
                    .padding(.horizontal, OC.Spacing.sm)
                    .padding(.vertical, OC.Spacing.xs)
                    .background(OC.Colors.accent.opacity(0.1))
                    .cornerRadius(OC.Radius.sm)
            }
            
            if !tool.description.isEmpty {
                Text(tool.description)
                    .font(OC.Typography.body)
                    .foregroundStyle(OC.Colors.textSecondary)
                    .padding(.top, OC.Spacing.xs)
            }
        }
        .ocCard()
    }
}
