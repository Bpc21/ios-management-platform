import Foundation
import Observation

@MainActor
@Observable
final class ConfigDataService {
    struct ConfigSetRequest: Codable {
        let raw: String
        let baseHash: String?
    }

    func loadConfig(gateway: GatewayService) async throws -> GatewayConfigSnapshotData {
        let configData = try await gateway.requestRaw(method: "config.get", paramsJSON: "{}")
        let root = try GatewayJSON.object(from: configData)
        return try UsersDataService.parseConfigSnapshot(from: root)
    }

    func saveConfig(gateway: GatewayService, rawConfigJSON: String, baseHash: String?) async throws {
        let request = ConfigSetRequest(raw: rawConfigJSON, baseHash: baseHash)
        let paramsJSON = try Self.encodeJSON(request)
        _ = try await gateway.requestRaw(method: "config.set", paramsJSON: paramsJSON)
    }

    static func prettyJSONString(from object: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return text
    }

    static func normalizedRawJSON(from text: String) throws -> String {
        guard let data = text.data(using: .utf8) else {
            throw NSError(domain: "ConfigDataService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Config text is not valid UTF-8"])
        }

        let object = try JSONSerialization.jsonObject(with: data)
        guard JSONSerialization.isValidJSONObject(object),
              let normalizedData = try? JSONSerialization.data(withJSONObject: object, options: [])
        else {
            throw NSError(domain: "ConfigDataService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Config must be a valid JSON object"])
        }

        guard let normalized = String(data: normalizedData, encoding: .utf8) else {
            throw NSError(domain: "ConfigDataService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unable to encode config JSON"])
        }

        return normalized
    }

    private static func encodeJSON<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        guard let json = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "ConfigDataService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unable to encode request"])
        }
        return json
    }
}
