import Foundation
import OpenClawProtocol
import Observation

struct ToolCatalogProfileItem: Identifiable, Hashable {
    let id: String
    let label: String
}

struct ToolCatalogEntryItem: Identifiable, Hashable {
    let id: String
    let label: String
    let description: String
    let source: String
    let defaultProfiles: [String]
}

struct ToolCatalogGroupItem: Identifiable, Hashable {
    let id: String
    let label: String
    let source: String
    let tools: [ToolCatalogEntryItem]
}

struct ToolsCatalogViewData: Hashable {
    let agentId: String
    let profiles: [ToolCatalogProfileItem]
    let groups: [ToolCatalogGroupItem]

    var allTools: [ToolCatalogEntryItem] {
        groups.flatMap(\.tools)
    }
}

@MainActor
@Observable
final class ToolsCatalogService {
    func loadCatalog(gateway: GatewayService, agentId: String? = nil) async throws -> ToolsCatalogViewData {
        struct Params: Codable {
            let agentId: String?
            let includePlugins: Bool
        }

        let params = Params(agentId: agentId, includePlugins: true)
        let json = try Self.encodeJSON(params)
        let data = try await gateway.requestRaw(method: "tools.catalog", paramsJSON: json)
        return try Self.parseCatalog(from: data)
    }

    static func parseCatalog(from data: Data) throws -> ToolsCatalogViewData {
        let root = try GatewayJSON.object(from: data)

        let rawProfiles = root["profiles"] as? [[String: Any]] ?? []
        let profiles = rawProfiles.compactMap { profile -> ToolCatalogProfileItem? in
            let idAny = profile["id"]
            let id: String
            if let idText = idAny as? String {
                id = idText
            } else if let idNumber = idAny as? NSNumber {
                id = idNumber.stringValue
            } else {
                return nil
            }

            return ToolCatalogProfileItem(
                id: id,
                label: (profile["label"] as? String) ?? id)
        }

        let rawGroups = root["groups"] as? [[String: Any]] ?? []
        let groups = rawGroups.compactMap { group -> ToolCatalogGroupItem? in
            guard let groupId = group["id"] as? String, !groupId.isEmpty else { return nil }
            let rawTools = group["tools"] as? [[String: Any]] ?? []

            let tools = rawTools.compactMap { tool -> ToolCatalogEntryItem? in
                guard let id = tool["id"] as? String, !id.isEmpty else { return nil }
                return ToolCatalogEntryItem(
                    id: id,
                    label: (tool["label"] as? String) ?? id,
                    description: (tool["description"] as? String) ?? "",
                    source: (tool["source"] as? String) ?? "core",
                    defaultProfiles: (tool["defaultProfiles"] as? [Any] ?? []).compactMap { value in
                        if let text = value as? String {
                            return text
                        }
                        if let number = value as? NSNumber {
                            return number.stringValue
                        }
                        return nil
                    })
            }
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }

            return ToolCatalogGroupItem(
                id: groupId,
                label: (group["label"] as? String) ?? groupId,
                source: (group["source"] as? String) ?? "core",
                tools: tools)
        }

        return ToolsCatalogViewData(
            agentId: (root["agentId"] as? String) ?? "",
            profiles: profiles,
            groups: groups)
    }

    private static func encodeJSON<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        guard let json = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "ToolsCatalogService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to encode request"])
        }
        return json
    }
}
