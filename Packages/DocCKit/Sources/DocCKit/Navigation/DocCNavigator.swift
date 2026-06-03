import Foundation

/// Coordinates DocC navigation state for SwiftUI renderers.
@MainActor
public protocol DocCNavigator: Observable {
    /// The currently selected documentation reference.
    var reference: Reference? { get }
    /// The currently selected framework or technology section.
    var technology: AppleTechnologies.FrameworkSection? { get }
    /// Whether the host app is currently presenting split-view navigation.
    var isUsingSplitView: Bool { get }
    /// URL scheme used to route generated documentation links back into the host app.
    var deepLinkScheme: DocCDeepLinkScheme { get }
    
    /// Selects a documentation reference.
    func setReference(_ reference: Reference?, forceHistory: Bool)
    /// Selects a framework or technology section.
    func setTechnology(_ technology: AppleTechnologies.FrameworkSection?, noHistory: Bool)
    /// Routes to the root homepage.
    func showHomepage()
}
