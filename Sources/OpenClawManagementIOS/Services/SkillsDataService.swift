import Foundation
import OpenClawProtocol
import Observation

struct SkillInstallOption: Identifiable, Hashable {
    let id: String
    let kind: String
    let label: String
    let bins: [String]
}

struct SkillRequirementSummary: Hashable {
    let bins: [String]
    let anyBins: [String]
    let env: [String]
    let config: [String]
    let os: [String]

    var isEmpty: Bool {
        bins.isEmpty && anyBins.isEmpty && env.isEmpty && config.isEmpty && os.isEmpty
    }
}

struct SkillStatusItem: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String?
    let source: String
    let eligible: Bool
    let disabled: Bool
    let requirements: SkillRequirementSummary
    let missing: SkillRequirementSummary
    let installOptions: [SkillInstallOption]

    var isGatewayReady: Bool {
        missing.isEmpty && !disabled
    }

    var requiredBins: [String] {
        requirements.bins
    }
}

struct SkillsNodeTarget: Identifiable, Hashable {
    let id: String
    let displayName: String
    let platform: String?
    let connected: Bool
}

struct NodeSkillReadiness: Hashable {
    let ready: Bool
    let missingBins: [String]
}

@MainActor
@Observable
final class SkillsDataService {
    struct SkillsInstallRequest: Codable {
        let name: String
        let installId: String
        let timeoutMs: Int?
    }

    struct NodeInvokeWhichRequest: Codable {
        let nodeId: String
        let command: String
        let params: Params
        let idempotencyKey: String

        struct Params: Codable {
            let bins: [String]
        }
    }

    func loadSkills(gateway: GatewayService, agentId: String? = nil) async throws -> [SkillStatusItem] {
        struct Params: Codable {
            let agentId: String?
        }

        let paramsJSON: String
        if let agentId {
            let params = Params(agentId: agentId)
            paramsJSON = try Self.encodeJSON(params)
        } else {
            paramsJSON = "{}"
        }

        let data = try await gateway.requestRaw(method: "skills.status", paramsJSON: paramsJSON)
        return try Self.parseSkills(from: data)
    }

    func loadNodeTargets(gateway: GatewayService) async throws -> [SkillsNodeTarget] {
        let data = try await gateway.requestRaw(method: "node.list", paramsJSON: "{}")
        let root = try GatewayJSON.object(from: data)
        guard let nodes = root["nodes"] as? [[String: Any]] else {
            return []
        }

        return nodes.compactMap { entry in
            guard let nodeId = entry["nodeId"] as? String, !nodeId.isEmpty else { return nil }
            let displayName = (entry["displayName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return SkillsNodeTarget(
                id: nodeId,
                displayName: (displayName?.isEmpty == false ? displayName : nil) ?? nodeId,
                platform: entry["platform"] as? String,
                connected: (entry["connected"] as? Bool) ?? false)
        }
        .sorted { lhs, rhs in
            if lhs.connected != rhs.connected {
                return lhs.connected && !rhs.connected
            }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    func checkNodeReadiness(
        gateway: GatewayService,
        nodeId: String,
        skills: [SkillStatusItem]) async throws -> [String: NodeSkillReadiness]
    {
        let uniqueBins = Array(Set(skills.flatMap(\.requiredBins))).sorted()
        if uniqueBins.isEmpty {
            return Self.evaluateNodeReadiness(availableBins: [], skills: skills)
        }

        let params = NodeInvokeWhichRequest(
            nodeId: nodeId,
            command: "system.which",
            params: .init(bins: uniqueBins),
            idempotencyKey: "skills-which-\(UUID().uuidString)")
        let json = try Self.encodeJSON(params)
        let data = try await gateway.requestRaw(method: "node.invoke", paramsJSON: json)

        let root = try GatewayJSON.object(from: data)
        let payload = root["payload"] as? [String: Any]
        let bins = payload?["bins"] as? [String: Any] ?? [:]

        let availableBins = Set(bins.compactMap { key, value -> String? in
            guard let path = value as? String, !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return key
        })

        return Self.evaluateNodeReadiness(availableBins: availableBins, skills: skills)
    }

    func installOnGateway(
        gateway: GatewayService,
        skillName: String,
        installId: String,
        timeoutMs: Int? = 120_000) async throws
    {
        let request = SkillsInstallRequest(name: skillName, installId: installId, timeoutMs: timeoutMs)
        let json = try Self.encodeJSON(request)
        _ = try await gateway.requestRaw(method: "skills.install", paramsJSON: json, timeout: 180)
    }

    static func parseSkills(from data: Data) throws -> [SkillStatusItem] {
        let root = try GatewayJSON.object(from: data)
        guard let rawSkills = root["skills"] as? [[String: Any]] else {
            return []
        }

        return rawSkills.compactMap { raw in
            let name = (raw["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !name.isEmpty else { return nil }

            let missing = parseRequirementSummary(raw["missing"] as? [String: Any])
            let requirements = parseRequirementSummary(raw["requirements"] as? [String: Any])
            let installOptions = (raw["install"] as? [[String: Any]] ?? []).compactMap(parseInstallOption)

            return SkillStatusItem(
                id: (raw["skillKey"] as? String) ?? name,
                name: name,
                description: raw["description"] as? String,
                source: (raw["source"] as? String) ?? "unknown",
                eligible: (raw["eligible"] as? Bool) ?? false,
                disabled: (raw["disabled"] as? Bool) ?? false,
                requirements: requirements,
                missing: missing,
                installOptions: installOptions)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func nodeInstallGuidance(for skill: SkillStatusItem) -> String {
        guard !skill.installOptions.isEmpty else {
            return "No automatic install recipe is published for this skill. Install required dependencies manually on the selected node and refresh readiness."
        }

        let lines = skill.installOptions.map { option in
            if option.bins.isEmpty {
                return "• \(option.label)"
            }
            return "• \(option.label) (bins: \(option.bins.joined(separator: ", ")))"
        }

        return (["Install this skill manually on the selected node using one of these recipes:"] + lines).joined(separator: "\n")
    }

    static func evaluateNodeReadiness(
        availableBins: Set<String>,
        skills: [SkillStatusItem]) -> [String: NodeSkillReadiness]
    {
        var result: [String: NodeSkillReadiness] = [:]
        for skill in skills {
            let missing = skill.requiredBins.filter { !availableBins.contains($0) }
            result[skill.id] = NodeSkillReadiness(ready: missing.isEmpty, missingBins: missing)
        }
        return result
    }

    private static func parseInstallOption(_ raw: [String: Any]) -> SkillInstallOption? {
        guard let id = raw["id"] as? String, !id.isEmpty else { return nil }
        let bins = (raw["bins"] as? [Any] ?? []).compactMap { $0 as? String }
        return SkillInstallOption(
            id: id,
            kind: (raw["kind"] as? String) ?? "unknown",
            label: (raw["label"] as? String) ?? id,
            bins: bins)
    }

    private static func parseRequirementSummary(_ raw: [String: Any]?) -> SkillRequirementSummary {
        SkillRequirementSummary(
            bins: parseStringArray(raw?["bins"]),
            anyBins: parseStringArray(raw?["anyBins"]),
            env: parseStringArray(raw?["env"]),
            config: parseStringArray(raw?["config"]),
            os: parseStringArray(raw?["os"]))
    }

    private static func parseStringArray(_ raw: Any?) -> [String] {
        (raw as? [Any] ?? [])
            .compactMap { value in
                if let text = value as? String {
                    return text.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                return nil
            }
            .filter { !$0.isEmpty }
    }

    private static func encodeJSON<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        guard let string = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "SkillsDataService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to encode request"])
        }
        return string
    }
}
