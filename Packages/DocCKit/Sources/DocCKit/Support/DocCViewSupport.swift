import SwiftUI

/// Cross-platform tappable control that behaves like a button on all supported platforms.
public struct DocCButton<Content: View>: View {
    private let action: () -> Void
    private let label: Content
    
    /// Creates a cross-platform button.
    ///
    /// - Parameters:
    ///   - action: Action performed when the control is activated.
    ///   - label: Label rendered inside the control.
    public init(action: @escaping () -> Void, @ViewBuilder label: () -> Content) {
        self.action = action
        self.label = label()
    }
    
    public var body: some View {
        #if os(macOS) || targetEnvironment(macCatalyst)
        Button(action: action) {
            label.contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        #else
        Button(action: action) {
            label
        }
        #endif
    }
}

/// Cross-platform link wrapper that opens URLs via gesture on macOS/Catalyst and `Link` elsewhere.
public struct DocCLink<Content: View>: View {
    private let destination: URL
    private let label: Content
    @Environment(\.openURL) private var openURL
    
    /// Creates a cross-platform link.
    ///
    /// - Parameters:
    ///   - destination: URL opened when the link is activated.
    ///   - label: Label rendered for the link.
    public init(destination: URL, @ViewBuilder label: () -> Content) {
        self.destination = destination
        self.label = label()
    }
    
    public var body: some View {
        #if os(macOS) || targetEnvironment(macCatalyst)
        label
            .onTapGesture {
                openURL(destination)
            }
        #else
        Link(destination: destination) {
            label
        }
        #endif
    }
}

/// Reference-aware navigation control used by DocCKit renderers.
public struct DocCReferenceNavigationLink<Content: View>: View {
    private let reference: Reference
    private let label: Content
    @Environment(\.docCNavigateToReference) private var navigateToReference
    
    /// Creates a reference navigation control.
    ///
    /// - Parameters:
    ///   - reference: Reference selected when the control is activated.
    ///   - label: Label rendered inside the control.
    public init(reference: Reference, @ViewBuilder label: () -> Content) {
        self.reference = reference
        self.label = label()
    }
    
    public var body: some View {
        DocCButton {
            navigateToReference?(reference)
        } label: {
            label
        }
        .disabled(navigateToReference == nil)
    }
}

extension View {
    /// Applies DocCKit's monospaced code-style font at a platform-appropriate headline size.
    @ViewBuilder
    public func docCCodeFont() -> some View {
        modifier(DocCCodeFontModifier())
    }
    
    // Handle for older than Xcode 26
    #if canImport(FoundationModels)
    /// Applies `backgroundExtensionEffect()` on supported OS versions and otherwise returns the view unchanged.
    @ViewBuilder
    public func docCBackgroundExtensionEffectIfAvailable() -> some View {
        if #available(iOS 26, macOS 26, visionOS 26, *) {
            backgroundExtensionEffect()
        } else {
            self
        }
    }
    #else
    /// Applies `backgroundExtensionEffect()` on supported OS versions and otherwise returns the view unchanged.
    @ViewBuilder
    public func docCBackgroundExtensionEffectIfAvailable() -> some View {
        self
    }
    #endif
}

extension Text {
    /// Applies DocCKit's monospaced code-style font at a platform-appropriate headline size.
    public func docCCodeFont() -> Text {
        font(.system(size: PlatformFont.preferredFont(forTextStyle: .headline).pointSize, weight: .regular, design: .monospaced))
    }
}

private struct DocCCodeFontModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: PlatformFont.preferredFont(forTextStyle: .headline).pointSize, weight: .regular, design: .monospaced))
    }
}

/// Renders a platform-styled chevron indicator used in list rows and navigation affordances.
public struct DocCChevronView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    public init() {}
    
    public var body: some View {
        Image(systemSymbol: .chevronRight)
            .resizable()
            .frame(width: 8, height: 12)
            #if os(visionOS)
            .foregroundStyle(colorScheme == .dark ? Color.primary : Color(platformColor: .systemGray3))
            #elseif os(macOS)
            .foregroundStyle(Color(platformColor: .systemGray).secondary)
            #else
            .foregroundStyle(Color(platformColor: .systemGray3))
            #endif
    }
}

/// Label style that places the icon after the text.
public struct DocCIconTrailingLabelStyle: LabelStyle {
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.title
            configuration.icon
        }
    }
}

extension LabelStyle where Self == DocCIconTrailingLabelStyle {
    /// Label style that places the icon after the text.
    public static var docCIconTrailing: Self {
        .init()
    }
}
