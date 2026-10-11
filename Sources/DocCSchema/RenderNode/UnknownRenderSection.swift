// A section whose `kind` this version of the schema does not know. The whole JSON object is
// kept so the page still decodes and the section re-encodes unchanged.

/// A render section of an unrecognised kind, preserved verbatim.
public struct UnknownRenderSection: RenderSection, Equatable {
    public var kind: RenderSectionKind

    /// The section as it appeared in the JSON.
    public var json: JSON

    public init(kind: RenderSectionKind, json: JSON) {
        self.kind = kind
        self.json = json
    }

    private enum CodingKeys: CodingKey {
        case kind
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decodeIfPresent(RenderSectionKind.self, forKey: .kind) ?? .unknown("")
        json = try JSON(from: decoder)
    }

    public func encode(to encoder: any Encoder) throws {
        try json.encode(to: encoder)
    }
}
