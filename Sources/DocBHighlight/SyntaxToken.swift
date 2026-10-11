/// A piece of a code listing and the highlighter's scopes on it, outermost first: the
/// classes the web renderer would put on the spans around it, without their prefix.
public struct SyntaxToken: Hashable, Sendable {
    public var text: String
    public var scopes: [String]

    public init(_ text: String, scopes: [String] = []) {
        self.text = text
        self.scopes = scopes
    }
}
