import Foundation

struct GatewayJSON {
    static func object(from data: Data) throws -> [String: Any] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "GatewayJSON", code: 1, userInfo: [NSLocalizedDescriptionKey: "Expected JSON object"])
        }
        return root
    }

    static func object(at path: [String], in object: [String: Any]) -> [String: Any]? {
        var current: Any = object
        for key in path {
            guard let dict = current as? [String: Any], let next = dict[key] else {
                return nil
            }
            current = next
        }
        return current as? [String: Any]
    }

    static func array(at path: [String], in object: [String: Any]) -> [Any]? {
        var current: Any = object
        for key in path {
            guard let dict = current as? [String: Any], let next = dict[key] else {
                return nil
            }
            current = next
        }
        return current as? [Any]
    }

    static func string(at path: [String], in object: [String: Any]) -> String? {
        var current: Any = object
        for key in path {
            guard let dict = current as? [String: Any], let next = dict[key] else {
                return nil
            }
            current = next
        }

        if let text = current as? String {
            return text
        }
        if let number = current as? NSNumber {
            return number.stringValue
        }
        return nil
    }

    static func bool(at path: [String], in object: [String: Any]) -> Bool? {
        var current: Any = object
        for key in path {
            guard let dict = current as? [String: Any], let next = dict[key] else {
                return nil
            }
            current = next
        }

        if let value = current as? Bool {
            return value
        }
        if let number = current as? NSNumber {
            return number.boolValue
        }
        if let text = current as? String {
            switch text.lowercased() {
            case "true", "1", "yes", "on": return true
            case "false", "0", "no", "off": return false
            default: return nil
            }
        }
        return nil
    }

    static func int(at path: [String], in object: [String: Any]) -> Int? {
        var current: Any = object
        for key in path {
            guard let dict = current as? [String: Any], let next = dict[key] else {
                return nil
            }
            current = next
        }

        if let value = current as? Int {
            return value
        }
        if let number = current as? NSNumber {
            return number.intValue
        }
        if let text = current as? String {
            return Int(text)
        }
        return nil
    }

    static func jsonString(from object: Any) -> String? {
        guard JSONSerialization.isValidJSONObject(object) else {
            return nil
        }
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
