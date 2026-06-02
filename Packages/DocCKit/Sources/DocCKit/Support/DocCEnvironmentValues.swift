import SwiftUI

extension View {
    /// Sets the URL scheme DocCKit uses when it synthesizes in-app documentation links.
    ///
    /// - Parameter scheme: Bare scheme such as `my-docs` or URL prefix such as `my-docs://`.
    public func docCDeepLinkScheme(_ scheme: String) -> some View {
        self.environment(\.docCDeepLinkScheme, DocCDeepLinkScheme(scheme))
    }
    
    /// Sets the URL scheme DocCKit uses when it synthesizes in-app documentation links.
    ///
    /// - Parameter scheme: Deep-link scheme descriptor supplied by the host app.
    public func docCDeepLinkScheme(_ scheme: DocCDeepLinkScheme) -> some View {
        self.environment(\.docCDeepLinkScheme, scheme)
    }
    
    /// Sets the tint for SwiftUI and exposes it to DocCKit renderers.
    public func docCTintColor(_ color: Color?) -> some View {
        self
            .environment(\.docCTintColor, color)
            .tint(color)
    }
}

/// Environment action used by renderers to request reference navigation.
public struct DocCReferenceNavigationAction: Sendable {
    private let action: @MainActor @Sendable (Reference) -> Void
    
    /// Creates a reference navigation action.
    ///
    /// - Parameter action: Closure invoked when a renderer selects a reference.
    public init(_ action: @escaping @MainActor @Sendable (Reference) -> Void) {
        self.action = action
    }
    
    /// Navigates to a reference.
    ///
    /// - Parameter reference: Reference selected by a renderer.
    @MainActor public func callAsFunction(_ reference: Reference) {
        action(reference)
    }
}

extension EnvironmentValues {
    /// Current custom DocC source used to resolve relative media and reference URLs.
    @Entry public var docCSite: DocCSource?
    /// Tint color used by inline links and code-styled reference text.
    @Entry public var docCTintColor: Color? = Color.accentColor
    /// Whether the host app is presenting split-view navigation.
    @Entry public var docCIsUsingSplitView = false
    /// URL scheme used when renderers synthesize in-app documentation links.
    @Entry public var docCDeepLinkScheme = DocCDeepLinkScheme.mainBundle ?? .doc
    /// Reference selection action supplied by the host app.
    @Entry public var docCNavigateToReference: DocCReferenceNavigationAction?
}
