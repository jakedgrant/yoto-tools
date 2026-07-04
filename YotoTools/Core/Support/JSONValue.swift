import Foundation

/// A loss-preserving representation of an arbitrary JSON value.
///
/// Yoto card payloads contain many fields we don't model explicitly. To update a
/// single track icon without dropping the rest of the card, we decode the whole
/// payload into `JSONValue`, mutate the one path we care about, and re-encode.
enum JSONValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}

// MARK: - Accessors

extension JSONValue {
    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var objectValue: [String: JSONValue]? {
        if case .object(let value) = self { return value }
        return nil
    }

    var arrayValue: [JSONValue]? {
        if case .array(let value) = self { return value }
        return nil
    }

    /// Reads a child value by object key. Returns `nil` for non-objects or missing keys.
    subscript(key: String) -> JSONValue? {
        objectValue?[key]
    }
}

// MARK: - Mutation

extension JSONValue {
    enum PathComponent: Equatable, Sendable {
        case key(String)
        case index(Int)
    }

    /// Sets `value` at the given path, creating intermediate objects as needed.
    /// Out-of-range array indices are ignored (no-op) to avoid corrupting data.
    mutating func set(_ value: JSONValue, at path: [PathComponent]) {
        guard let first = path.first else {
            self = value
            return
        }
        let rest = Array(path.dropFirst())
        switch first {
        case .key(let key):
            var object = objectValue ?? [:]
            var child = object[key] ?? .object([:])
            child.set(value, at: rest)
            object[key] = child
            self = .object(object)
        case .index(let index):
            var array = arrayValue ?? []
            guard index >= 0, index < array.count else { return }
            var child = array[index]
            child.set(value, at: rest)
            array[index] = child
            self = .array(array)
        }
    }

    /// Removes the value at the given path. Missing intermediates and
    /// out-of-range indices are a no-op, mirroring `set`.
    mutating func remove(at path: [PathComponent]) {
        guard let first = path.first else { return }
        let rest = Array(path.dropFirst())
        switch first {
        case .key(let key):
            guard var object = objectValue else { return }
            if rest.isEmpty {
                object.removeValue(forKey: key)
            } else {
                guard var child = object[key] else { return }
                child.remove(at: rest)
                object[key] = child
            }
            self = .object(object)
        case .index(let index):
            guard var array = arrayValue, index >= 0, index < array.count else { return }
            if rest.isEmpty {
                array.remove(at: index)
            } else {
                var child = array[index]
                child.remove(at: rest)
                array[index] = child
            }
            self = .array(array)
        }
    }
}
