import Foundation
import OpenClawProtocol
import Observation

struct NodeSummaryItem: Identifiable, Hashable {
    let id: String
    let displayName: String
    let platform: String
    let version: String
    let commands: [String]
    let capabilities: [String]
    let connected: Bool
    let paired: Bool
    let connectedAtMs: Int?
}

struct NodePairRequestItem: Identifiable, Hashable {
    let id: String
    let displayName: String
    let platform: String
    let version: String
    let createdAtMs: Int?
}

struct DeviceTokenInfoItem: Hashable {
    let role: String
    let scopes: [String]
    let createdAtMs: Int?
    let lastUsedAtMs: Int?
}

struct DeviceSummaryItem: Identifiable, Hashable {
    let id: String
    let displayName: String
    let platform: String
    let clientId: String
    let clientMode: String
    let role: String
    let scopes: [String]
    let createdAtMs: Int?
    let approvedAtMs: Int?
    let tokens: [DeviceTokenInfoItem]

    var rotateRole: String {
        tokens.first?.role ?? (role.isEmpty ? "operator" : role)
    }
}

struct DevicePairRequestItem: Identifiable, Hashable {
    let id: String
    let displayName: String
    let platform: String
    let clientId: String
    let clientMode: String
    let role: String
    let scopes: [String]
    let createdAtMs: Int?
}

struct NodePairingSnapshot: Hashable {
    let nodes: [NodeSummaryItem]
    let pendingPairings: [NodePairRequestItem]
}

struct DevicePairingSnapshot: Hashable {
    let pairedDevices: [DeviceSummaryItem]
    let pendingDevices: [DevicePairRequestItem]
}

@MainActor
@Observable
final class NodesDevicesService {
    var isLoading = false
    var nodes: [NodeSummaryItem] = []
    var devices: [DeviceSummaryItem] = []
    struct RequestById: Codable {
        let requestId: String
    }

    struct DeviceRemoveRequest: Codable {
        let deviceId: String
    }

    struct DeviceRotateRequest: Codable {
        let deviceId: String
        let role: String
        let scopes: [String]?
    }

    func loadNodes(gateway: GatewayService) async throws -> NodePairingSnapshot {
        async let listData = gateway.requestRaw(method: "node.list", paramsJSON: "{}")
        async let pairData = gateway.requestRaw(method: "node.pair.list", paramsJSON: "{}")

        let (nodesData, pairsData) = try await (listData, pairData)

        let nodes = try Self.parseNodes(from: nodesData)
        let pending = try Self.parseNodePendingPairings(from: pairsData)
        return NodePairingSnapshot(nodes: nodes, pendingPairings: pending)
    }

    func loadDevices(gateway: GatewayService) async throws -> DevicePairingSnapshot {
        let data = try await gateway.requestRaw(method: "device.pair.list", paramsJSON: "{}")
        return try Self.parseDevices(from: data)
    }

    func approveNodePairing(gateway: GatewayService, requestId: String) async throws {
        let json = try Self.encodeJSON(RequestById(requestId: requestId))
        _ = try await gateway.requestRaw(method: "node.pair.approve", paramsJSON: json)
    }

    func rejectNodePairing(gateway: GatewayService, requestId: String) async throws {
        let json = try Self.encodeJSON(RequestById(requestId: requestId))
        _ = try await gateway.requestRaw(method: "node.pair.reject", paramsJSON: json)
    }

    func approveDevicePairing(gateway: GatewayService, requestId: String) async throws {
        let json = try Self.encodeJSON(RequestById(requestId: requestId))
        _ = try await gateway.requestRaw(method: "device.pair.approve", paramsJSON: json)
    }

    func rejectDevicePairing(gateway: GatewayService, requestId: String) async throws {
        let json = try Self.encodeJSON(RequestById(requestId: requestId))
        _ = try await gateway.requestRaw(method: "device.pair.reject", paramsJSON: json)
    }

    func removeDevice(gateway: GatewayService, deviceId: String) async throws {
        let json = try Self.encodeJSON(DeviceRemoveRequest(deviceId: deviceId))
        _ = try await gateway.requestRaw(method: "device.pair.remove", paramsJSON: json)
    }

    func rotateDeviceToken(gateway: GatewayService, device: DeviceSummaryItem) async throws {
        let request = DeviceRotateRequest(deviceId: device.id, role: device.rotateRole, scopes: nil)
        let json = try Self.encodeJSON(request)
        _ = try await gateway.requestRaw(method: "device.token.rotate", paramsJSON: json)
    }

    static func parseNodes(from data: Data) throws -> [NodeSummaryItem] {
        let root = try GatewayJSON.object(from: data)
        let entries = root["nodes"] as? [[String: Any]] ?? []

        return entries.compactMap { node in
            guard let nodeId = node["nodeId"] as? String, !nodeId.isEmpty else { return nil }
            let display = (node["displayName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return NodeSummaryItem(
                id: nodeId,
                displayName: (display?.isEmpty == false ? display : nil) ?? nodeId,
                platform: (node["platform"] as? String) ?? "unknown",
                version: (node["version"] as? String) ?? "—",
                commands: Self.parseStringArray(node["commands"]),
                capabilities: Self.parseStringArray(node["caps"]),
                connected: (node["connected"] as? Bool) ?? false,
                paired: (node["paired"] as? Bool) ?? false,
                connectedAtMs: Self.asInt(node["connectedAtMs"]))
        }
        .sorted { lhs, rhs in
            if lhs.connected != rhs.connected {
                return lhs.connected && !rhs.connected
            }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    static func parseNodePendingPairings(from data: Data) throws -> [NodePairRequestItem] {
        let root = try GatewayJSON.object(from: data)
        let pending = root["pending"] as? [[String: Any]] ?? []

        return pending.compactMap { request in
            let requestId = (request["requestId"] as? String) ?? (request["id"] as? String) ?? ""
            guard !requestId.isEmpty else { return nil }

            return NodePairRequestItem(
                id: requestId,
                displayName: (request["displayName"] as? String) ?? requestId,
                platform: (request["platform"] as? String) ?? "unknown",
                version: (request["version"] as? String) ?? "—",
                createdAtMs: Self.asInt(request["createdAtMs"]))
        }
        .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    static func parseDevices(from data: Data) throws -> DevicePairingSnapshot {
        let root = try GatewayJSON.object(from: data)
        let paired = root["paired"] as? [[String: Any]] ?? []
        let pending = root["pending"] as? [[String: Any]] ?? []

        let pairedDevices = paired.compactMap { raw -> DeviceSummaryItem? in
            guard let deviceId = raw["deviceId"] as? String, !deviceId.isEmpty else { return nil }
            let tokensRaw = raw["tokens"] as? [[String: Any]] ?? []
            let tokens = tokensRaw.map { token in
                DeviceTokenInfoItem(
                    role: (token["role"] as? String) ?? "operator",
                    scopes: parseStringArray(token["scopes"]),
                    createdAtMs: asInt(token["createdAtMs"]),
                    lastUsedAtMs: asInt(token["lastUsedAtMs"]))
            }

            return DeviceSummaryItem(
                id: deviceId,
                displayName: (raw["displayName"] as? String) ?? deviceId,
                platform: (raw["platform"] as? String) ?? "unknown",
                clientId: (raw["clientId"] as? String) ?? "",
                clientMode: (raw["clientMode"] as? String) ?? "",
                role: (raw["role"] as? String) ?? "operator",
                scopes: parseStringArray(raw["scopes"]),
                createdAtMs: asInt(raw["createdAtMs"]),
                approvedAtMs: asInt(raw["approvedAtMs"]),
                tokens: tokens)
        }
        .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }

        let pendingDevices = pending.compactMap { raw -> DevicePairRequestItem? in
            let requestId = (raw["requestId"] as? String) ?? (raw["id"] as? String) ?? ""
            guard !requestId.isEmpty else { return nil }

            return DevicePairRequestItem(
                id: requestId,
                displayName: (raw["displayName"] as? String) ?? requestId,
                platform: (raw["platform"] as? String) ?? "unknown",
                clientId: (raw["clientId"] as? String) ?? "",
                clientMode: (raw["clientMode"] as? String) ?? "",
                role: (raw["role"] as? String) ?? "operator",
                scopes: parseStringArray(raw["scopes"]),
                createdAtMs: asInt(raw["createdAtMs"]))
        }
        .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }

        return DevicePairingSnapshot(pairedDevices: pairedDevices, pendingDevices: pendingDevices)
    }

    private static func parseStringArray(_ value: Any?) -> [String] {
        (value as? [Any] ?? [])
            .compactMap { $0 as? String }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func asInt(_ value: Any?) -> Int? {
        if let intValue = value as? Int {
            return intValue
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let text = value as? String {
            return Int(text)
        }
        return nil
    }

    private static func encodeJSON<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        guard let json = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "NodesDevicesService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to encode request"])
        }
        return json
    }
}
