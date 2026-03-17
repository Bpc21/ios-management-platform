import SwiftUI
import OpenClawKit

struct CronView: View {
    @Environment(GatewayService.self) private var gateway
    @State private var cronService = CronService()
    
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
                            CronJobRow(job: job, service: cronService)
                        }
                    }
                }
                .padding(OC.Spacing.md)
            }
            .navigationTitle("Cron Jobs")
            .navigationBarTitleDisplayMode(.inline)
            .background(OC.Colors.background)
            .task {
                do {
                    cronService.isLoading = true
                    cronService.jobs = try await cronService.loadJobs(gateway: gateway)
                } catch {}
                cronService.isLoading = false
            }
            .refreshable {
                do {
                    cronService.isLoading = true
                    cronService.jobs = try await cronService.loadJobs(gateway: gateway)
                } catch {}
                cronService.isLoading = false
            }
        }
    }
}

struct CronJobRow: View {
    let job: CronJobItem
    let service: CronService
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
                        Task { try? await service.setEnabled(gateway: gateway, jobId: job.id, enabled: newValue) }
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
                    Task { try? await service.remove(gateway: gateway, jobId: job.id) }
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
                    Task { try? await service.runNow(gateway: gateway, jobId: job.id) }
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
