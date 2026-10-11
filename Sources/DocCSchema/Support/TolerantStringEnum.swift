// A string-backed enum that keeps values it does not recognise instead of failing to decode.
// Render JSON grows new discriminator and style values over time; a reader must degrade
// gracefully on them, and re-encode them unchanged.

/// A string-backed enum with an `unknown` case that preserves unrecognised raw values.
///
/// Conforming enums implement `init(rawValue:)` non-failably, mapping unrecognised strings to
/// ``unknown(_:)``, and get `Codable` for free as a single JSON string.
public protocol TolerantStringEnum: RawRepresentable, Codable, Hashable where RawValue == String {
    /// A value this version of the schema does not know. The raw string is preserved and re-encoded unchanged.
    static func unknown(_ rawValue: String) -> Self
}

extension TolerantStringEnum {
    public init(from decoder: any Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: rawValue) ?? .unknown(rawValue)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
