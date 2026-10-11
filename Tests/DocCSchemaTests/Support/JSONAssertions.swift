// Helpers for shape tests: decode a JSON literal into a schema type, re-encode it,
// and check that every key and value in the original survives the round trip.
// Tests use synthetic sample content only; no real documentation text is embedded.

import Foundation
import Testing
@testable import DocCSchema

/// Decodes `json` as `T` using the same decoder configuration the library ships.
func decode<T: Decodable>(_ type: T.Type = T.self, _ json: String) throws -> T {
    try RenderJSONDecoder.makeDecoder().decode(T.self, from: Data(json.utf8))
}

/// Decodes `json`, encodes the result, and asserts the original JSON is a subset of the
/// re-encoded JSON. Returns the decoded value so a test can make further shape assertions.
///
/// Subset rather than equality: encoders legitimately add keys with default values
/// (for example `copyToClipboard: false`) and may omit keys upstream never encodes.
/// Pass `omitting` for original keys the encoder is known to drop.
@discardableResult
func roundTrip<T: Codable>(
    _ type: T.Type = T.self,
    _ json: String,
    omitting: Set<String> = [],
    sourceLocation: SourceLocation = #_sourceLocation
) throws -> T {
    let value = try decode(T.self, json)
    let encoded = try RenderJSONEncoder.makeEncoder().encode(value)
    let original = try JSONSerialization.jsonObject(with: Data(json.utf8))
    let reencoded = try JSONSerialization.jsonObject(with: encoded)
    let missing = jsonSubsetViolations(expected: original, actual: reencoded, path: "$", omitting: omitting)
    #expect(missing.isEmpty, "Round trip lost or changed: \(missing.joined(separator: "; "))", sourceLocation: sourceLocation)
    return value
}

/// Returns a list of JSON paths where `expected` is not contained in `actual`.
func jsonSubsetViolations(expected: Any, actual: Any, path: String, omitting: Set<String>) -> [String] {
    switch (expected, actual) {
    case let (e as [String: Any], a as [String: Any]):
        return e.flatMap { key, value -> [String] in
            if omitting.contains(key) { return [] }
            guard let actualValue = a[key] else { return ["\(path).\(key) missing"] }
            return jsonSubsetViolations(expected: value, actual: actualValue, path: "\(path).\(key)", omitting: omitting)
        }
    case let (e as [Any], a as [Any]):
        guard e.count == a.count else { return ["\(path) count \(e.count) != \(a.count)"] }
        return zip(e, a).enumerated().flatMap { index, pair in
            jsonSubsetViolations(expected: pair.0, actual: pair.1, path: "\(path)[\(index)]", omitting: omitting)
        }
    default:
        // NSNumber/NSString bridging makes `isEqual` the right comparison for scalars.
        return (expected as AnyObject).isEqual(actual) ? [] : ["\(path) \(expected) != \(actual)"]
    }
}
