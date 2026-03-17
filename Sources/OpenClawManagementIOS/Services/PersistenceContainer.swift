import Foundation
import SwiftData

@MainActor
final class PersistenceContainer {
    static let shared: ModelContainer = {
        do {
            return try makeContainer()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    static func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            AppUser.self,
        ])

        let storeURL = URL.applicationSupportDirectory
            .appending(path: "OpenClawManagement", directoryHint: .isDirectory)
            .appending(path: "openclaw.store")

        let config = ModelConfiguration(
            "openclaw-management",
            schema: schema,
            url: storeURL,
            allowsSave: true
        )

        return try ModelContainer(for: schema, configurations: [config])
    }
}
