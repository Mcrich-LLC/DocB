//
//  AddTechnologyView.swift
//  Developer Documentation
//
//  Created by Morris Richman on 2/28/26.
//

import NukeUI
import SwiftUI
import SwiftData

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
    @Environment(\.modelContext) var modelContext
    /// Persisted DocC site models currently available in local storage.
    @Query var docCSites: [DocCSite]
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
            title: "Swift-Syntax",
            subtitle: "A library for working with Swift code.",
            image: nil,
            baseURL: URL(string: "https://swiftpackageindex.com/swiftlang/swift-syntax/main")!
        ),
        SuggestedTechnology(
            title: "WWDC Notes",
            subtitle: "Session notes shared by the community for the community.",
            image: nil,
            baseURL: URL(string: "https://wwdcnotes.com")!
        )
    ]
    
    /// Returns whether a featured technology is currently being added.
    private func isSuggestedLoading(_ technology: SuggestedTechnology) -> Bool {
        technologiesAddInProgress.contains(where: { $0.baseURL == technology.baseURL })
            || sourceRemovalsInProgress.contains(technology.baseURL)
    }
    
    /// Returns whether a featured technology is already added.
    private func isSuggestedAdded(_ technology: SuggestedTechnology) -> Bool {
        documentationViewModel.technologies.docCSites.contains(where: { $0.url == technology.baseURL })
    }

    public var body: some View {
        List {
            Section("Our Favorite Projects") {
                ForEach(featuredTechnologies) { technology in
                    Button {
                        toggleSuggestedTechnology(technology)
                    } label: {
                        HStack {
                            if isSuggestedLoading(technology) {
                                ProgressView()
                                    .controlSize(.small)
                                    .frame(width: 15, height: 15)
                            } else {
                                Image(systemSymbol: isSuggestedAdded(technology) ? .checkmarkSquareFill : .square)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 15, height: 15)
                                    .contentTransition(.symbolEffect(.replace))
                                    .foregroundStyle(isSuggestedAdded(technology) ? Color.accentColor : .primary)
                            }
                            SuggestedTechnologyRow(technology: technology)
                                .frame(minHeight: 50)
                            Spacer()
                        }
                    }
                    .disabled(isSuggestedLoading(technology))
                    .animation(.easeInOut, value: isSuggestedAdded(technology))
                    .animation(.easeInOut, value: isSuggestedLoading(technology))
                }
            }
            .buttonStyle(.plain)
            
            Section("Add Some Custom Ones") {
                ForEach(customSites, id: \.id) { technology in
                    HStack {
                        EnteredTechnologyRow(technology: technology)
                        Spacer()
                        Button {
                            removeTechnology(technology)
                        } label: {
                            if isRemovingTechnology(technology) {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Label("Remove", systemSymbol: .trash)
                            }
                        }
                        .labelStyle(.iconOnly)
                        .disabled(isRemovingTechnology(technology))
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
    
    /// Adds or removes a featured technology depending on current selection state.
    private func toggleSuggestedTechnology(_ technology: SuggestedTechnology) {
        if isSuggestedAdded(technology) {
            removeDocCSite(url: technology.baseURL)
        } else {
            technologiesAddInProgress.insert(technology)
            Task {
                await Task.yield()
                await addDocCSite(url: technology.baseURL, overrideName: technology.title)
                technologiesAddInProgress.remove(technology)
            }
        }
    }
    
    /// Returns whether a technology is currently being removed.
    ///
    /// - Parameter technology: Technology source to check.
    /// - Returns: `true` when a removal task is active for this source.
    private func isRemovingTechnology(_ technology: TechnologyTypes) -> Bool {
        sourceRemovalsInProgress.contains(technology.url)
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
                try await documentationViewModel.deleteTechnology(technology, modelContainer: modelContext.container)
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
            return
        }
        
        guard let site = try? docCSites.first(where: { $0.url == url })?.dto else {
            return
        }
        removeTechnology(.docC(site))
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
            try await documentationViewModel.addTechnology(baseUrl: baseUrl, modelContext: modelContext, overrideName: overrideName)
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
                    baseURL: URL(string: "\(Constants.aDeveloperURLBase)/documentation")!)
            )
        case .docC(let docCSiteDTO):
            if let site = docCSiteDTO.groups.first, let path = URL(string: site.path ?? "") {
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
