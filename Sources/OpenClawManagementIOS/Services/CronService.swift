import Foundation
import OpenClawProtocol
import Observation

enum CronScheduleKind: String, CaseIterable, Codable {
    case every
    case at
    case cron
}

enum CronEveryUnit: String, CaseIterable, Codable {
    case minutes
    case hours
    case days

    var milliseconds: Int {
        switch self {
        case .minutes: 60_000
        case .hours: 3_600_000
        case .days: 86_400_000
        }
    }
}

enum CronPayloadKind: String, CaseIterable, Codable {
    case agentTurn
    case systemEvent
}

enum CronSessionTarget: String, CaseIterable, Codable {
    case isolated
    case main
}

struct CronJobItem: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    var enabled: Bool
    let agentId: String?
    let sessionKey: String?
    let sessionTarget: CronSessionTarget
    let schedule: [String: AnyHashable]
    let payload: [String: AnyHashable]
    let state: [String: AnyHashable]
    let createdAtMs: Int?
    let updatedAtMs: Int?

    var scheduleSummary: String {
        guard let kind = schedule["kind"] as? String else { return "Unknown" }
        switch kind {
        case "every":
            if let everyMs = schedule["everyMs"] as? Int {
                if everyMs % 86_400_000 == 0 {
                    return "Every \(everyMs / 86_400_000) day(s)"
                }
                if everyMs % 3_600_000 == 0 {
                    return "Every \(everyMs / 3_600_000) hour(s)"
                }
                return "Every \(everyMs / 60_000) minute(s)"
            }
            return "Every"
        case "at":
            if let at = schedule["at"] as? String {
                return "At \(at)"
            }
            return "At"
        case "cron":
            let expr = (schedule["expr"] as? String) ?? ""
            return expr.isEmpty ? "Cron" : expr
        default:
            return kind
        }
    }

    var payloadSummary: String {
        guard let kind = payload["kind"] as? String else { return "" }
        switch kind {
        case "agentTurn":
            return (payload["message"] as? String) ?? ""
        case "systemEvent":
            return (payload["text"] as? String) ?? ""
        default:
            return ""
        }
    }

    var lastRunAtMs: Int? {
        state["lastRunAtMs"] as? Int
    }

    var nextRunAtMs: Int? {
        state["nextRunAtMs"] as? Int
    }

    var lastStatus: String {
        (state["lastStatus"] as? String) ?? "unknown"
    }
}

struct CronRunItem: Identifiable, Hashable {
    let id: String
    let jobId: String
    let status: String
    let deliveryStatus: String
    let startedAtMs: Int?
    let finishedAtMs: Int?
    let durationMs: Int?
    let error: String?
}

struct CronEditorForm: Hashable {
    var name: String = ""
    var description: String = ""
    var enabled: Bool = true

    var scheduleKind: CronScheduleKind = .every
    var everyAmount: Int = 30
    var everyUnit: CronEveryUnit = .minutes
    var atDate: Date = Date().addingTimeInterval(300)
    var cronExpr: String = "0 7 * * *"
    var cronTimeZone: String = ""

    var sessionTarget: CronSessionTarget = .isolated
    var agentId: String = ""
    var sessionKey: String = ""

    var payloadKind: CronPayloadKind = .agentTurn
    var payloadText: String = ""

    mutating func alignPayloadToTarget() {
        if sessionTarget == .main {
            payloadKind = .systemEvent
        } else if payloadKind == .systemEvent {
            payloadKind = .agentTurn
        }
    }
}

@MainActor
@Observable
final class CronService {
    var isLoading = false
    var jobs: [CronJobItem] = []
    func loadJobs(gateway: GatewayService) async throws -> [CronJobItem] {
        struct Params: Codable {
            let includeDisabled: Bool
            let limit: Int
            let offset: Int
            let sortBy: String
            let sortDir: String
        }

        let json = try Self.encodeJSON(Params(includeDisabled: true, limit: 200, offset: 0, sortBy: "nextRunAtMs", sortDir: "asc"))
        let data = try await gateway.requestRaw(method: "cron.list", paramsJSON: json)
        return try Self.parseJobs(from: data)
    }

    func loadRuns(gateway: GatewayService, jobId: String?) async throws -> [CronRunItem] {
        struct Params: Codable {
            let scope: String
            let id: String?
            let limit: Int
            let offset: Int
            let sortDir: String
        }

        let params = Params(scope: jobId == nil ? "all" : "job", id: jobId, limit: 50, offset: 0, sortDir: "desc")
        let json = try Self.encodeJSON(params)
        let data = try await gateway.requestRaw(method: "cron.runs", paramsJSON: json)
        return try Self.parseRuns(from: data)
    }

    func addJob(gateway: GatewayService, form: CronEditorForm) async throws {
        let payload = try makeAddPayload(form: form)
        let json = try Self.serializeParams(payload)
        _ = try await gateway.requestRaw(method: "cron.add", paramsJSON: json)
    }

    func updateJob(gateway: GatewayService, jobId: String, form: CronEditorForm) async throws {
        let payload = try makeUpdatePayload(jobId: jobId, form: form)
        let json = try Self.serializeParams(payload)
        _ = try await gateway.requestRaw(method: "cron.update", paramsJSON: json)
    }

    func setEnabled(gateway: GatewayService, jobId: String, enabled: Bool) async throws {
        let payload: [String: Any] = [
            "id": jobId,
            "patch": ["enabled": enabled],
        ]
        let json = try Self.serializeParams(payload)
        _ = try await gateway.requestRaw(method: "cron.update", paramsJSON: json)
    }

    func runNow(gateway: GatewayService, jobId: String) async throws {
        struct Params: Codable {
            let id: String
            let mode: String
        }

        let json = try Self.encodeJSON(Params(id: jobId, mode: "force"))
        _ = try await gateway.requestRaw(method: "cron.run", paramsJSON: json)
    }

    func remove(gateway: GatewayService, jobId: String) async throws {
        struct Params: Codable {
            let id: String
        }

        let json = try Self.encodeJSON(Params(id: jobId))
        _ = try await gateway.requestRaw(method: "cron.remove", paramsJSON: json)
    }

    func validate(_ form: CronEditorForm) throws {
        let name = form.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw NSError(domain: "CronService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cron name is required"])
        }

        let payload = form.payloadText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !payload.isEmpty else {
            throw NSError(domain: "CronService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Payload text is required"])
        }

        switch form.scheduleKind {
        case .every:
            guard form.everyAmount > 0 else {
                throw NSError(domain: "CronService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Every interval must be greater than zero"])
            }
        case .at:
            break
        case .cron:
            guard !form.cronExpr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw NSError(domain: "CronService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Cron expression is required"])
            }
        }

        if form.sessionTarget == .main && form.payloadKind != .systemEvent {
            throw NSError(domain: "CronService", code: 5, userInfo: [NSLocalizedDescriptionKey: "Main sessionTarget requires systemEvent payload"])
        }

        if form.sessionTarget == .isolated && form.payloadKind != .agentTurn {
            throw NSError(domain: "CronService", code: 6, userInfo: [NSLocalizedDescriptionKey: "Isolated sessionTarget requires agentTurn payload"])
        }
    }

    func form(from job: CronJobItem) -> CronEditorForm {
        var form = CronEditorForm()
        form.name = job.name
        form.description = job.description
        form.enabled = job.enabled
        form.sessionTarget = job.sessionTarget
        form.agentId = job.agentId ?? ""
        form.sessionKey = job.sessionKey ?? ""

        if let kind = job.payload["kind"] as? String {
            switch kind {
            case "systemEvent":
                form.payloadKind = .systemEvent
                form.payloadText = (job.payload["text"] as? String) ?? ""
            default:
                form.payloadKind = .agentTurn
                form.payloadText = (job.payload["message"] as? String) ?? ""
            }
        }

        if let kind = job.schedule["kind"] as? String {
            switch kind {
            case "at":
                form.scheduleKind = .at
                if let at = job.schedule["at"] as? String,
                   let date = ISO8601DateFormatter().date(from: at)
                {
                    form.atDate = date
                }
            case "cron":
                form.scheduleKind = .cron
                form.cronExpr = (job.schedule["expr"] as? String) ?? form.cronExpr
                form.cronTimeZone = (job.schedule["tz"] as? String) ?? ""
            default:
                form.scheduleKind = .every
                if let everyMs = job.schedule["everyMs"] as? Int, everyMs > 0 {
                    if everyMs % CronEveryUnit.days.milliseconds == 0 {
                        form.everyUnit = .days
                        form.everyAmount = max(1, everyMs / CronEveryUnit.days.milliseconds)
                    } else if everyMs % CronEveryUnit.hours.milliseconds == 0 {
                        form.everyUnit = .hours
                        form.everyAmount = max(1, everyMs / CronEveryUnit.hours.milliseconds)
                    } else {
                        form.everyUnit = .minutes
                        form.everyAmount = max(1, everyMs / CronEveryUnit.minutes.milliseconds)
                    }
                }
            }
        }

        return form
    }

    func makeAddPayload(form: CronEditorForm) throws -> [String: Any] {
        try validate(form)
        return try buildAddOrPatchPayload(from: form)
    }

    func makeUpdatePayload(jobId: String, form: CronEditorForm) throws -> [String: Any] {
        let patch = try makeAddPayload(form: form)
        return [
            "id": jobId,
            "patch": patch,
        ]
    }

    static func parseJobs(from data: Data) throws -> [CronJobItem] {
        let root = try GatewayJSON.object(from: data)
        let entries = root["jobs"] as? [[String: Any]] ?? []

        return entries.compactMap { raw in
            guard let id = raw["id"] as? String, !id.isEmpty else { return nil }
            let scheduleRaw = raw["schedule"] as? [String: Any] ?? [:]
            let payloadRaw = raw["payload"] as? [String: Any] ?? [:]
            let stateRaw = raw["state"] as? [String: Any] ?? [:]

            let sessionTargetRaw = (raw["sessionTarget"] as? String) ?? "isolated"
            let sessionTarget = CronSessionTarget(rawValue: sessionTargetRaw) ?? .isolated

            return CronJobItem(
                id: id,
                name: (raw["name"] as? String) ?? id,
                description: (raw["description"] as? String) ?? "",
                enabled: (raw["enabled"] as? Bool) ?? true,
                agentId: raw["agentId"] as? String,
                sessionKey: raw["sessionKey"] as? String,
                sessionTarget: sessionTarget,
                schedule: Self.hashableDictionary(from: scheduleRaw),
                payload: Self.hashableDictionary(from: payloadRaw),
                state: Self.hashableDictionary(from: stateRaw),
                createdAtMs: Self.asInt(raw["createdAtMs"]),
                updatedAtMs: Self.asInt(raw["updatedAtMs"]))
        }
    }

    static func parseRuns(from data: Data) throws -> [CronRunItem] {
        let root = try GatewayJSON.object(from: data)
        let entries = root["entries"] as? [[String: Any]] ?? []

        return entries.compactMap { raw in
            guard let id = raw["id"] as? String, !id.isEmpty else { return nil }
            return CronRunItem(
                id: id,
                jobId: (raw["jobId"] as? String) ?? "",
                status: (raw["status"] as? String) ?? "unknown",
                deliveryStatus: (raw["deliveryStatus"] as? String) ?? "",
                startedAtMs: Self.asInt(raw["startedAtMs"]),
                finishedAtMs: Self.asInt(raw["finishedAtMs"]),
                durationMs: Self.asInt(raw["durationMs"]),
                error: raw["error"] as? String)
        }
    }

    private func buildAddOrPatchPayload(from form: CronEditorForm) throws -> [String: Any] {
        let schedule: [String: Any]
        switch form.scheduleKind {
        case .every:
            schedule = [
                "kind": "every",
                "everyMs": form.everyAmount * form.everyUnit.milliseconds,
            ]
        case .at:
            schedule = [
                "kind": "at",
                "at": ISO8601DateFormatter().string(from: form.atDate),
            ]
        case .cron:
            var cron: [String: Any] = [
                "kind": "cron",
                "expr": form.cronExpr.trimmingCharacters(in: .whitespacesAndNewlines),
            ]
            let tz = form.cronTimeZone.trimmingCharacters(in: .whitespacesAndNewlines)
            if !tz.isEmpty {
                cron["tz"] = tz
            }
            schedule = cron
        }

        let payloadText = form.payloadText.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload: [String: Any]
        switch form.payloadKind {
        case .agentTurn:
            payload = [
                "kind": "agentTurn",
                "message": payloadText,
            ]
        case .systemEvent:
            payload = [
                "kind": "systemEvent",
                "text": payloadText,
            ]
        }

        var result: [String: Any] = [
            "name": form.name.trimmingCharacters(in: .whitespacesAndNewlines),
            "description": form.description.trimmingCharacters(in: .whitespacesAndNewlines),
            "enabled": form.enabled,
            "schedule": schedule,
            "sessionTarget": form.sessionTarget.rawValue,
            "wakeMode": "now",
            "payload": payload,
        ]

        let trimmedAgent = form.agentId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAgent.isEmpty {
            result["agentId"] = trimmedAgent
        }

        let trimmedSessionKey = form.sessionKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSessionKey.isEmpty {
            result["sessionKey"] = trimmedSessionKey
        }

        return result
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

    private static func hashableDictionary(from dict: [String: Any]) -> [String: AnyHashable] {
        var result: [String: AnyHashable] = [:]
        for (key, value) in dict {
            if let hashable = value as? AnyHashable {
                result[key] = hashable
                continue
            }
            if let nested = value as? [String: Any] {
                result[key] = GatewayJSON.jsonString(from: nested) ?? "{}"
                continue
            }
            if let array = value as? [Any] {
                result[key] = array.compactMap { $0 as? String }.joined(separator: ",")
            }
        }
        return result
    }

    private static func encodeJSON<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        guard let json = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "CronService", code: 99, userInfo: [NSLocalizedDescriptionKey: "Unable to encode request"])
        }
        return json
    }

    private static func serializeParams(_ params: [String: Any]) throws -> String {
        guard JSONSerialization.isValidJSONObject(params) else {
            throw NSError(domain: "CronService", code: 100, userInfo: [NSLocalizedDescriptionKey: "Invalid cron request payload"])
        }

        let data = try JSONSerialization.data(withJSONObject: params, options: [])
        guard let json = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "CronService", code: 101, userInfo: [NSLocalizedDescriptionKey: "Unable to serialize request payload"])
        }
        return json
    }
}
