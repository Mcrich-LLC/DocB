//
//  AddTechnologyView.swift
//  Developer Documentation
//
//  Created by Morris Richman on 2/28/26.
//

import Kingfisher
import SwiftUI
import SwiftData

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
struct AddTechnologySheetView: View {
    var body: some View {
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
struct AddTechnologyView: View {
    /// Shared documentation state for adding/removing technologies.
    @Environment(DocumentationViewModel.self) var documentationViewModel
    /// SwiftData context used for persistence-backed source changes.
    @Environment(\.modelContext) var modelContext
    /// Persisted DocC site models currently available in local storage.
    @Query var docCSites: [DocCSite]
    /// User-entered custom URL text before normalization.
    @State private var addDocumentationUrl = ""
    /// Captures errors to present through the common error alert modifier.
    @State private var errorAlert: Error?
    /// Tracks in-flight featured add operations to keep UI state responsive.
    @State private var technologiesAddInProgress: Set<SuggestedTechnology> = []
    
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
            title: "CubiomesKit",
            subtitle: "Generate, inspect, and view Minecraft Java worlds.",
            image: URL(string: "https://cubiomeskit.alidade.dev/images/CubiomesKit/Icon.png")!,
            baseURL: URL(string: "https://cubiomeskit.alidade.dev")!
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
    
    /// Returns whether a featured technology is already added or currently being added.
    private func isSuggestedAdded(_ technology: SuggestedTechnology) -> Bool {
        documentationViewModel.technologies.docCSites.contains(where: { $0.url == technology.baseURL }) || technologiesAddInProgress.contains(where: { $0.baseURL == technology.baseURL })
    }

    var body: some View {
        List {
            Section("Our Favorite Projects") {
                ForEach(featuredTechnologies) { technology in
                    Button {
                        toggleSuggestedTechnology(technology)
                    } label: {
                        HStack {
                            Image(systemSymbol: isSuggestedAdded(technology) ? .checkmarkCircleFill : .circle)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 15, height: 15)
                                .animation(.easeInOut, value: documentationViewModel.technologies)
                                .contentTransition(.symbolEffect(.replace))
                                .foregroundStyle(isSuggestedAdded(technology) ? Color.accentColor : .primary)
                            SuggestedTechnologyRow(technology: technology)
                                .frame(minHeight: 50)
                            Spacer()
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            
            Section("Add Some Custom Ones") {
                ForEach(customSites, id: \.id) { technology in
                    HStack {
                        EnteredTechnologyRow(technology: technology)
                        Spacer()
                        Button {
                            do {
                                try documentationViewModel.deleteTechnology(technology, modelContext: modelContext)
                            } catch {
                                self.errorAlert = error
                            }
                        } label: {
                            Label("Remove", systemSymbol: .trash)
                        }
                        .labelStyle(.iconOnly)
                    }
                }
                HStack {
                    TextField("https://docs.example.com", text: $addDocumentationUrl)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            Task {
                                await addCustomDocCSite()
                            }
                        }
                    Button("Add") {
                        Task {
                            await addCustomDocCSite()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("Add Sources")
        .alert(for: $errorAlert)
    }
    
    /// Adds or removes a featured technology depending on current selection state.
    private func toggleSuggestedTechnology(_ technology: SuggestedTechnology) {
        if isSuggestedAdded(technology) {
            technologiesAddInProgress.remove(technology)
            removeDocCSite(url: technology.baseURL)
        } else {
            Task {
                technologiesAddInProgress.insert(technology)
                await addDocCSite(url: technology.baseURL, overrideName: technology.title)
                technologiesAddInProgress.remove(technology)
            }
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
        guard let site = try? docCSites.first(where: { $0.url == url })?.dto else {
            return
        }
        do {
            try documentationViewModel.deleteTechnology(.docC(site), modelContext: modelContext)
        } catch {
            self.errorAlert = error
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
            try await documentationViewModel.addTechnology(baseUrl: baseUrl, modelContext: modelContext, overrideName: overrideName)
        } catch {
            self.errorAlert = error
        }
    }
}

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
                KFImage(image)
                    .resizable()
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
