// A reference whose `type` this version of the schema does not know. The whole JSON object is
// kept so the page still decodes and the reference re-encodes unchanged.

/// A render reference of an unrecognised type, preserved verbatim.
public struct UnknownRenderReference: RenderReference, Equatable {
    public var type: RenderReferenceType

    public var identifier: RenderReferenceIdentifier

    /// The reference as it appeared in the JSON.
    public var json: JSON

    public init(type: RenderReferenceType, identifier: RenderReferenceIdentifier, json: JSON) {
        self.type = type
        self.identifier = identifier
        self.json = json
    }

    private enum CodingKeys: CodingKey {
        case type, identifier
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(RenderReferenceType.self, forKey: .type) ?? .unknown("")
        identifier = try container.decodeIfPresent(RenderReferenceIdentifier.self, forKey: .identifier) ?? RenderReferenceIdentifier("")
        json = try JSON(from: decoder)
    }

    public func encode(to encoder: any Encoder) throws {
        try json.encode(to: encoder)
    }
}
