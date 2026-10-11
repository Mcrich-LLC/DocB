// The legal notices block developer.apple.com attaches to its homepage and technologies catalog
// render nodes. Not part of upstream DocC.

/// Copyright and policy links attached to a developer.apple.com render node.
public struct RenderLegalNotices: Codable, Equatable {
    /// The copyright line, which may contain HTML entities.
    public var copyright: String

    /// A link to the privacy policy.
    public var privacyPolicy: String

    /// A link to the terms of use.
    public var termsOfUse: String

    public init(copyright: String, privacyPolicy: String, termsOfUse: String) {
        self.copyright = copyright
        self.privacyPolicy = privacyPolicy
        self.termsOfUse = termsOfUse
    }
}
