import Foundation
import OpenClawProtocol
import Observation

struct UsersAgentSummary: Hashable, @unchecked Sendable {
    let id: String
    let displayName: String
    let workspace: String?
    let skills: [String]
}

struct UsersOverviewRow: Identifiable, Hashable, @unchecked Sendable {
    let id: String
    let phone: String
    let isAllowlisted: Bool
    let agents: [UsersAgentSummary]
}

struct GatewayConfigSnapshotData: @unchecked Sendable {
    let hash: String
    let raw: String
    let config: [String: Any]
}

struct UsersOverviewData: @unchecked Sendable {
    let rows: [UsersOverviewRow]
    let allowlist: [String]
    let configSnapshot: GatewayConfigSnapshotData
}

@MainActor
@Observable
final class UsersDataService {
    struct ConfigSetRequest: Codable {
        let raw: String
        let baseHash: String?
    }

    func loadOverview(gateway: GatewayService) async throws -> UsersOverviewData {
        async let configData = gateway.requestRaw(method: "config.get", paramsJSON: "{}")
        async let channelsData = gateway.requestRaw(method: "channels.status", paramsJSON: "{\"probe\":true}")

        let configRoot = try GatewayJSON.object(from: await configData)
        let channelsRoot = (try? GatewayJSON.object(from: await channelsData)) ?? [:]

        let snapshot = try Self.parseConfigSnapshot(from: configRoot)
        let allowlist = Self.extractAllowlist(config: snapshot.config, channelsStatus: channelsRoot)
        let rows = Self.buildRows(config: snapshot.config, allowlist: allowlist)

        return UsersOverviewData(rows: rows, allowlist: allowlist, configSnapshot: snapshot)
    }

    func saveAllowlist(gateway: GatewayService, updatedAllowlist: [String]) async throws {
        let configData = try await gateway.requestRaw(method: "config.get", paramsJSON: "{}")
        let configRoot = try GatewayJSON.object(from: configData)
        let snapshot = try Self.parseConfigSnapshot(from: configRoot)
        let updatedConfig = Self.updatedConfig(snapshot.config, withAllowlist: updatedAllowlist)

        guard let raw = GatewayJSON.jsonString(from: updatedConfig) else {
            throw NSError(domain: "UsersDataService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to serialize updated config"])
        }

        let request = ConfigSetRequest(raw: raw, baseHash: snapshot.hash)
        let json = try Self.encodeJSON(request)
        _ = try await gateway.requestRaw(method: "config.set", paramsJSON: json)
    }

    static func parseConfigSnapshot(from root: [String: Any]) throws -> GatewayConfigSnapshotData {
        guard let config = root["config"] as? [String: Any] else {
            throw NSError(domain: "UsersDataService", code: 1, userInfo: [NSLocalizedDescriptionKey: "config.get missing config payload"])
        }

        let hash = (root["hash"] as? String) ?? ""
        let raw = (root["raw"] as? String) ?? (GatewayJSON.jsonString(from: config) ?? "{}")
        return GatewayConfigSnapshotData(hash: hash, raw: raw, config: config)
    }

    static func buildRows(config: [String: Any], allowlist: [String]) -> [UsersOverviewRow] {
        let agents = buildAgentMap(config: config)
        let bindings = buildPhoneBindingMap(config: config)

        let allPhones = Set(allowlist).union(bindings.keys)

        return allPhones.map { phone in
            let linkedAgentIds = Array(bindings[phone] ?? []).sorted()
            let linkedAgents = linkedAgentIds.compactMap { agents[$0] }
            return UsersOverviewRow(
                id: phone,
                phone: phone,
                isAllowlisted: allowlist.contains(phone),
                agents: linkedAgents)
        }
        .sorted { $0.phone.localizedCaseInsensitiveCompare($1.phone) == .orderedAscending }
    }

    static func extractAllowlist(config: [String: Any], channelsStatus: [String: Any]) -> [String] {
        var set = Set<String>()

        if let channelAllow = GatewayJSON.array(at: ["channels", "whatsapp", "allowFrom"], in: config) {
            for value in channelAllow.compactMap(asString) {
                set.insert(value)
            }
        }

        if let accounts = GatewayJSON.object(at: ["channels", "whatsapp", "accounts"], in: config) {
            for account in accounts.values {
                guard let dict = account as? [String: Any], let values = dict["allowFrom"] as? [Any] else { continue }
                for value in values.compactMap(asString) {
                    set.insert(value)
                }
            }
        }

        if let accounts = GatewayJSON.array(at: ["channelAccounts", "whatsapp"], in: channelsStatus) {
            for account in accounts {
                guard let dict = account as? [String: Any], let values = dict["allowFrom"] as? [Any] else { continue }
                for value in values.compactMap(asString) {
                    set.insert(value)
                }
            }
        }

        return normalizeAllowlist(Array(set))
    }

    static func normalizeAllowlist(_ values: [String]) -> [String] {
        Array(Set(values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }))
        .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    static func updatedConfig(_ config: [String: Any], withAllowlist values: [String]) -> [String: Any] {
        var updatedConfig = config
        let normalized = normalizeAllowlist(values)

        setValue(normalized, at: ["channels", "whatsapp", "allowFrom"], in: &updatedConfig)

        if var accounts = GatewayJSON.object(at: ["channels", "whatsapp", "accounts"], in: updatedConfig) {
            for key in accounts.keys {
                if var account = accounts[key] as? [String: Any] {
                    account["allowFrom"] = normalized
                    accounts[key] = account
                }
            }
            setValue(accounts, at: ["channels", "whatsapp", "accounts"], in: &updatedConfig)
        }

        return updatedConfig
    }

    private static func buildAgentMap(config: [String: Any]) -> [String: UsersAgentSummary] {
        guard let agents = GatewayJSON.array(at: ["agents", "list"], in: config) else {
            return [:]
        }

        var map: [String: UsersAgentSummary] = [:]
        for agent in agents {
            guard let dict = agent as? [String: Any], let id = dict["id"] as? String, !id.isEmpty else { continue }

            let identityName = GatewayJSON.string(at: ["identity", "name"], in: dict)
            let displayName = (dict["name"] as? String) ?? identityName ?? id
            let workspace = dict["workspace"] as? String
            let skills = (dict["skills"] as? [Any] ?? []).compactMap(asString)

            map[id] = UsersAgentSummary(
                id: id,
                displayName: displayName,
                workspace: workspace,
                skills: skills)
        }
        return map
    }

    private static func buildPhoneBindingMap(config: [String: Any]) -> [String: Set<String>] {
        guard let bindings = config["bindings"] as? [Any] else {
            return [:]
        }

        var map: [String: Set<String>] = [:]
        for entry in bindings {
            guard let dict = entry as? [String: Any],
                  let agentId = dict["agentId"] as? String,
                  let match = dict["match"] as? [String: Any],
                  (match["channel"] as? String) == "whatsapp",
                  let peer = match["peer"] as? [String: Any],
                  (peer["kind"] as? String) == "direct",
                  let peerId = peer["id"] as? String,
                  !peerId.isEmpty
            else {
                continue
            }
            map[peerId, default: []].insert(agentId)
        }
        return map
    }

    private static func asString(_ value: Any) -> String? {
        if let text = value as? String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return nil
    }

    private static func setValue(_ value: Any, at path: [String], in object: inout [String: Any]) {
        guard let first = path.first else { return }
        if path.count == 1 {
            object[first] = value
            return
        }

        var child = object[first] as? [String: Any] ?? [:]
        setValue(value, at: Array(path.dropFirst()), in: &child)
        object[first] = child
    }

    private static func encodeJSON<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        guard let json = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "UsersDataService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to encode request"])
        }
        return json
    }
}
