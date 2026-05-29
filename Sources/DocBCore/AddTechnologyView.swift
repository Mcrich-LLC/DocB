//
//  AddTechnologyView.swift
//  Developer Documentation
//
//  Created by Morris Richman on 2/28/26.
//

import NukeUI
import SwiftUI
import SwiftData
import DocCKit

/// Curated source descriptor used by the add-technology UI.
private struct SuggestedTechnology: Identifiable, Hashable {
    /// Stable local identifier for SwiftUI diffing.
    let id = UUID()
    /// Display title shown in the featured technologies list.
    let title: String
    /// Optional descriptive subtitle shown under the title.
    let subtitle: String?
    /// Optional icon/logo URL for the suggested technology.
    let image: URL?
    /// Base documentation URL used to add/remove the source.
    let baseURL: URL
}

/// Presents the add-technology flow inside a navigation container with close controls.
public struct AddTechnologySheetView: View {
    public init() {}
    public var body: some View {
        NavigationStack {
            AddTechnologyView()
                .toolbar {
                    ToolbarCloseButton()
                }
                .frame(minHeight: 400)
        }
    }
}

/// Lists featured and custom documentation sources and supports adding or removing DocC technologies.
public struct AddTechnologyView: View {
    public init() {}
    
    @Environment(DocumentationViewModel.self) var documentationViewModel
    /// User-entered custom URL text before normalization.
    @State private var addDocumentationUrl = ""
    /// Captures errors to present through the common error alert modifier.
    @State private var errorAlert: Error?
    /// Tracks in-flight featured add operations to keep UI state responsive.
    @State private var technologiesAddInProgress: Set<SuggestedTechnology> = []
    /// Tracks custom source insertion so the add controls do not enqueue duplicate work.
    @State private var isAddingCustomDocCSite = false
    /// Source URLs currently being removed.
    @State private var sourceRemovalsInProgress: Set<URL> = []
    
    /// Non-featured technologies currently configured by the user.
    private var customSites: [TechnologyTypes] {
        documentationViewModel.technologies.filter { tech in
            switch tech {
            case .apple: return true
            case .docC(let site):
                return !featuredTechnologies.contains(where: { $0.baseURL == site.url })
            }
        }
    }

    /// Curated list of quick-add documentation sources.
    private let featuredTechnologies: [SuggestedTechnology] = [
        SuggestedTechnology(
            title: "RevenueCat",
            subtitle: "😻 In-App Subscriptions Made Easy 😻",
            image: nil,
            baseURL: URL(string: "https://swiftpackageindex.com/RevenueCat/purchases-ios/main")!
        ),
        SuggestedTechnology(
            title: "Swift.org",
            subtitle: "All of the documentation from swift.org",
            image: nil,
            baseURL: URL(string: "https://www.swift.org/")!
        ),
        SuggestedTechnology(
            title: "Swift-Testing",
            subtitle: "Create and run tests for your Swift packages and Xcode projects.",
            image: nil,
            baseURL: URL(string: "https://swiftpackageindex.com/swiftlang/swift-testing/main")!
        ),
        SuggestedTechnology(
            title: "Nuke",
            subtitle: "A powerful image loading system for Apple platforms.",
            image: nil,
            baseURL: URL(string: "https://kean-docs.github.io/nuke/documentation")!
        ),
        SuggestedTechnology(
            title: "WWDC Notes",
            subtitle: "Session notes shared by the community for the community.",
            image: nil,
            baseURL: URL(string: "https://wwdcnotes.com")!
        )
    ]
    
    public var body: some View {
        let addedFeaturedSourceURLs = Set(documentationViewModel.technologies.docCSites.map(\.url))
        let featuredLoadingURLs = Set(technologiesAddInProgress.map(\.baseURL)).union(sourceRemovalsInProgress)
        
        List {
            Section("Our Favorite Projects") {
                ForEach(featuredTechnologies) { technology in
                    let isAdded = addedFeaturedSourceURLs.contains(technology.baseURL)
                    let isLoading = featuredLoadingURLs.contains(technology.baseURL)
                    var binding: Binding<Bool> {
                        Binding(get: { isAdded }, set: { bool in
                            toggleSuggestedTechnology(bool, technology: technology)
                        })
                    }
                    
                    HStack {
                        #if os(macOS)
                        toggleView(binding: binding, isLoading: isLoading)
                            .toggleStyle(.checkbox)
                        #endif
                        Button {
                            toggleSuggestedTechnology(!isAdded, technology: technology)
                        } label: {
                            HStack {
                                SuggestedTechnologyRow(technology: technology)
                                    .frame(minHeight: 50)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        #if !os(macOS)
                        toggleView(binding: binding, isLoading: isLoading)
                        #endif
                    }
                    .disabled(isLoading)
                    .animation(.easeInOut, value: isAdded)
                    .animation(.easeInOut, value: isLoading)
                }
            }
            .buttonStyle(.plain)
            
            Section("Add Some Custom Ones") {
                ForEach(customSites, id: \.id) { technology in
                    let isRemoving = sourceRemovalsInProgress.contains(technology.url)
                    
                    HStack {
                        EnteredTechnologyRow(technology: technology)
                        Spacer()
                        Button {
                            removeTechnology(technology)
                        } label: {
                            if isRemoving {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Label("Remove", systemSymbol: .trash)
                            }
                        }
                        .labelStyle(.iconOnly)
                        .disabled(isRemoving)
                    }
                }
                HStack {
                    TextField("https://docs.example.com", text: $addDocumentationUrl)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            startCustomDocCSiteAdd()
                        }
                    Button {
                        startCustomDocCSiteAdd()
                    } label: {
                        if isAddingCustomDocCSite {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Add")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isAddingCustomDocCSite)
                }
            }
        }
        .navigationTitle("Add Sources")
        .alert(for: $errorAlert)
    }
    
    @ViewBuilder
    private func toggleView(binding: Binding<Bool>, isLoading: Bool) -> some View {
        if isLoading {
            ProgressView()
                .controlSize(.small)
                .frame(width: 15, height: 15)
        } else {
            Toggle(isOn: binding, label: {})
                .labelsHidden()
        }
    }
    
    /// Adds or removes a featured technology depending on current selection state.
    ///
    /// - Parameters:
    ///   - technology: Suggested source selected by the user.
    ///   - isAdded: Snapshot of whether this source is already loaded.
    private func toggleSuggestedTechnology(_ bool: Bool, technology: SuggestedTechnology) {
        if bool {
            technologiesAddInProgress.insert(technology)
            Task {
                await Task.yield()
                await addDocCSite(url: technology.baseURL, overrideName: technology.title)
                technologiesAddInProgress.remove(technology)
            }
        } else {
            removeDocCSite(url: technology.baseURL)
        }
    }
    
    /// Removes a technology while keeping the Add Sources UI responsive.
    ///
    /// - Parameter technology: Technology source to remove.
    private func removeTechnology(_ technology: TechnologyTypes) {
        guard !sourceRemovalsInProgress.contains(technology.url) else { return }
        
        sourceRemovalsInProgress.insert(technology.url)
        
        Task {
            await Task.yield()
            do {
                try await documentationViewModel.deleteTechnology(technology)
            } catch {
                self.errorAlert = error
            }
            sourceRemovalsInProgress.remove(technology.url)
        }
    }
    
    /// Starts a custom source add after immediately updating loading state.
    private func startCustomDocCSiteAdd() {
        guard !isAddingCustomDocCSite else { return }
        
        isAddingCustomDocCSite = true
        
        Task {
            await Task.yield()
            await addCustomDocCSite()
            isAddingCustomDocCSite = false
        }
    }
    
    /// Normalizes and validates the entered custom URL, then adds it as a DocC source.
    private func addCustomDocCSite() async {
        var addDocumentationUrl = self.addDocumentationUrl.replacingOccurrences(of: "http://", with: "https://")
        
        if !addDocumentationUrl.contains("://") {
            addDocumentationUrl = "https://\(addDocumentationUrl)"
        }
        
        guard let url = URL(string: addDocumentationUrl) else {
            return
        }
        
        await addDocCSite(url: url)
        self.addDocumentationUrl = ""
    }
    
    /// Removes a persisted DocC source that matches the provided base URL.
    private func removeDocCSite(url: URL) {
        if let site = documentationViewModel.technologies.docCSites.first(where: { $0.url == url }) {
            removeTechnology(.docC(site))
        }
    }
    
    /// Adds a DocC source by extracting a normalized base URL and loading its index.
    private func addDocCSite(url: URL, overrideName: String? = nil) async {
        guard let scheme = url.scheme,
              let host = url.host
        else {
            return
        }
        
        let limitedPath: String
        
        if let indexRange = url.path().firstRange(of: "/documentation") {
            limitedPath = String(url.path().prefix(upTo: indexRange.lowerBound))
        } else {
            limitedPath = url.path()
        }
        
        guard let baseUrl = URL(string: "\(scheme)://\(host)\(limitedPath)") else {
            return
        }
        
        do {
            try await documentationViewModel.addTechnology(baseUrl: baseUrl, overrideName: overrideName)
        } catch {
            self.errorAlert = error
        }
    }
}

/// Row renderer for technologies already entered/added by the user.
private struct EnteredTechnologyRow: View {
    /// Technology entry currently displayed in the custom list.
    let technology: TechnologyTypes
    
    var body: some View {
        switch technology {
        case .apple:
            SuggestedTechnologyRow(
                technology: .init(
                    title: "Apple Developer Documentation",
                    subtitle: "The documentation from Apple's Official website",
                    image: nil,
                    baseURL: URL(string: "\(DocCConstants.aDeveloperURLBase)/documentation")!)
            )
        case .docC(let source):
            if let site = source.groups.first, let path = URL(string: site.path ?? "") {
                SuggestedTechnologyRow(technology: .init(title: site.title, subtitle: nil, image: nil, baseURL: path))
            }
        }
    }
}

/// Row renderer for a curated suggested technology entry.
private struct SuggestedTechnologyRow: View {
    /// Curated technology metadata used to populate title, subtitle, and icon.
    let technology: SuggestedTechnology

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading) {
                Text(technology.title)
                    .font(.headline)
                if let subtitle = technology.subtitle {
                    Text(subtitle)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let image = technology.image {
                LazyImage(url: image) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                }
                .frame(width: 50, height: 50)
            }
        }
    }
}

#Preview {
    @Previewable @State var documentationViewModel: DocumentationViewModel =
        .init()
    NavigationStack {
        AddTechnologyView()
            .environment(documentationViewModel)
            .modelContainer(for: [DocCSite.self], isAutosaveEnabled: true)
    }
}
