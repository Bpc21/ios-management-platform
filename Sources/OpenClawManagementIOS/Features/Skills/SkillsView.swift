import SwiftUI
import OpenClawKit

struct SkillsView: View {
    @Environment(GatewayService.self) private var gateway
    @State private var skillsService = SkillsDataService()
    
    @State private var skills: [SkillStatusItem]? = nil
    @State private var isLoading = false
    @State private var errorText: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: OC.Spacing.md) {
                    
                    if let errorText {
                        Text(errorText)
                            .foregroundStyle(OC.Colors.destructive)
                            .padding(.top, OC.Spacing.xl)
                    }
                    
                    if isLoading && skills == nil {
                        ProgressView("Loading skills...")
                            .padding(.top, OC.Spacing.xxl)
                    } else if let loadedSkills = skills {
                        if loadedSkills.isEmpty {
                            Text("No active skills found.")
                                .font(OC.Typography.bodyMedium)
                                .foregroundStyle(OC.Colors.textTertiary)
                                .padding(.top, OC.Spacing.xxl)
                        } else {
                            ForEach(loadedSkills, id: \.id) { skill in
                                SkillRow(skill: skill, service: skillsService)
                            }
                        }
                    }
                }
                .padding(OC.Spacing.md)
            }
            .navigationTitle("Skills")
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
                let items = try await skillsService.loadSkills(gateway: gateway)
                await MainActor.run {
                    self.skills = items
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

struct SkillRow: View {
    let skill: SkillStatusItem
    let service: SkillsDataService
    
    var body: some View {
        VStack(alignment: .leading, spacing: OC.Spacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: OC.Spacing.xs) {
                    Text(skill.name)
                        .font(OC.Typography.h3)
                        .foregroundStyle(OC.Colors.textPrimary)
                    
                    Text(skill.id)
                        .font(OC.Typography.monoSmall)
                        .foregroundStyle(OC.Colors.textTertiary)
                }
                
                Spacer()
                
                Text(skill.source)
                    .font(OC.Typography.caption)
                    .foregroundStyle(OC.Colors.textSecondary)
                    .padding(.horizontal, OC.Spacing.sm)
                    .padding(.vertical, OC.Spacing.xs)
                    .background(OC.Colors.surfaceElevated)
                    .cornerRadius(OC.Radius.sm)
            }
            
            if let desc = skill.description {
                Text(desc)
                    .font(OC.Typography.body)
                    .foregroundStyle(OC.Colors.textSecondary)
                    .padding(.top, OC.Spacing.xs)
            }
        }
        .ocCard()
    }
}
