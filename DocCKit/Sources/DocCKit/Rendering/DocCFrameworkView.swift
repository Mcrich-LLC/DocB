import SwiftUI

/// Renders a DocC framework payload.
public struct DocCFrameworkView<Navigator: DocCNavigator>: View {
    /// Framework payload to render.
    private let framework: Framework
    /// Framework section represented by this payload.
    private let frameworkSection: AppleTechnologies.FrameworkSection
    /// Host-app navigation coordinator.
    @State private var navigator: Navigator
    
    /// Creates a framework renderer.
    ///
    /// - Parameters:
    ///   - framework: Framework payload to render.
    ///   - frameworkSection: Framework section represented by this payload.
    ///   - navigator: Host-app navigation coordinator.
    public init(framework: Framework, frameworkSection: AppleTechnologies.FrameworkSection, navigator: Navigator) {
        self.framework = framework
        self.frameworkSection = frameworkSection
        self.navigator = navigator
    }
    
    /// Creates a framework renderer from a render-ready page.
    ///
    /// - Parameters:
    ///   - page: Render-ready framework page.
    ///   - navigator: Host-app navigation coordinator.
    public init(page: DocCFrameworkPage, navigator: Navigator) {
        self.init(framework: page.framework, frameworkSection: page.frameworkSection, navigator: navigator)
    }
    
    public var body: some View {
        List {
            Section {
                FrameworkReferenceRow(reference: frameworkSection.frameworkReference, title: frameworkSection.title)
                    .id(frameworkSection.frameworkReference.identifier)
            }
            
            ForEach(framework.topicSections ?? []) { section in
                Section {
                    ForEach(section.identifiers, id: \.self) { identifier in
                        if let reference = conditionedReference(framework.references[identifier]), let title = reference.title {
                            FrameworkReferenceRow(reference: reference, title: title)
                                .id(identifier)
                        }
                    }
                } header: {
                    if let title = section.title {
                        Text(title)
                    }
                }
                .headerProminence(.increased)
            }
            
            Section {} footer: {
                if let legalNotices = framework.legalNotices {
                    DocCLegalNoticesView(legalNotices: legalNotices)
                        .padding(.bottom)
                }
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .background(Color(platformColor: .systemBackground))
        .environment(\.docCIsUsingSplitView, navigator.isUsingSplitView)
        .environment(\.docCDeepLinkScheme, navigator.deepLinkScheme)
        .environment(\.docCNavigateToReference, DocCReferenceNavigationAction { reference in
            navigator.setReference(reference, forceHistory: false)
        })
    }
    
    private func conditionedReference(_ reference: Reference?) -> Reference? {
        guard var reference else { return nil }
        reference.docCSite = reference.docCSite ?? frameworkSection.docCSite
        return reference
    }
}

private struct FrameworkReferenceRow: View {
    let reference: Reference
    let title: String
    
    var body: some View {
        DocCReferenceNavigationLink(reference: reference) {
            Label {
                HStack {
                    Text(title)
                    
                    if reference.beta == true {
                        ArticleBadge(badge: .beta)
                    }
                    
                    if reference.deprecated == true {
                        ArticleBadge(badge: .deprecated)
                    }
                    
                    Spacer()
                    DocCChevronView()
                }
            } icon: {
                Image(systemSymbol: reference.role?.labelIcon ?? .textDocument)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
