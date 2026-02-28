//
//  AddTechnologyView.swift
//  Developer Documentation
//
//  Created by Morris Richman on 2/28/26.
//

import Kingfisher
import SwiftUI

private struct SuggestedTechnology: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let image: URL?
    let baseURL: URL
}

struct AddTechnologyView: View {
    @Environment(DocumentationViewModel.self) var documentationViewModel
    @Environment(\.modelContext) var modelContext
    @State private var addDocumentationUrl = ""
    
    private var customSites: [TechnologyTypes] {
        documentationViewModel.technologies.filter({ tech in !featuredTechnologies.contains(where: { tech.names.contains($0.title) }) })
    }

    private let featuredTechnologies: [SuggestedTechnology] = [
        SuggestedTechnology(
            title: "CubiomesKit",
            subtitle: "Generate, inspect, and view Minecraft Java worlds.",
            image: URL(string: "https://cubiomeskit.alidade.dev/images/CubiomesKit/Icon@2x.png")!,
            baseURL: URL(string: "https://cubiomeskit.alidade.dev")!
        ),
        SuggestedTechnology(
            title: "DocC",
            subtitle: "Produce rich API reference documentation and interactive tutorials for your Swift framework or package.",
            image: nil,
            baseURL: URL(string: "https://www.swift.org/documentation/docc/")!
        ),
        SuggestedTechnology(
            title: "Swift-Testing",
            subtitle: "Create and run tests for your Swift packages and Xcode projects.",
            image: nil,
            baseURL: URL(string: "https://swiftpackageindex.com/swiftlang/swift-testing/6.2.4/documentation/testing")!
        ),
        SuggestedTechnology(
            title: "Swift-Syntax",
            subtitle: "A library for working with Swift code.",
            image: nil,
            baseURL: URL(string: "https://swiftpackageindex.com/swiftlang/swift-syntax/602.0.0/documentation/swiftsyntax")!
        )
    ]

    var body: some View {
        List {
            Section {
                Text("Add Some DocC Sites")
                    .font(.title)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .listRowSeparator(.hidden, edges: .all)
            Section("Our Favorite Projects") {
                ForEach(featuredTechnologies) { technology in
                    SuggestedTechnologyRow(technology: technology)
                }
            }
            
            Section("Add Some Custom Ones") {
                ForEach(customSites, id: \.id) { technology in
                    EnteredTechnologyRow(technology: technology)
                }
                HStack {
                    TextField("https://developer.apple.com", text: $addDocumentationUrl)
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
    }
    
    func addCustomDocCSite() async {
        defer {
            self.addDocumentationUrl = ""
        }
        var addDocumentationUrl = self.addDocumentationUrl.replacingOccurrences(of: "http://", with: "https://")
        
        if !addDocumentationUrl.contains("://") {
            addDocumentationUrl = "https://\(addDocumentationUrl)"
        }
        
        guard let url = URL(string: addDocumentationUrl),
              let scheme = url.scheme,
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
        
        await documentationViewModel.addTechnology(baseUrl: baseUrl, modelContext: modelContext)
    }
}

private struct EnteredTechnologyRow: View {
    let technology: TechnologyTypes
    
    var body: some View {
        switch technology {
        case .apple:
            SuggestedTechnologyRow(
                technology: .init(
                    title: "Apple Developer Documentation",
                    subtitle: "All of the documentation from developer.apple.com/documentation",
                    image: nil,
                    baseURL: URL(string: "https://developer.apple.com/documentation")!)
            )
        case .docC(let docCSiteDTO):
            if let site = docCSiteDTO.groups.first, let path = URL(string: site.path ?? "") {
                SuggestedTechnologyRow(technology: .init(title: site.title, subtitle: nil, image: nil, baseURL: path))
            }
        }
    }
}

private struct SuggestedTechnologyRow: View {
    let technology: SuggestedTechnology

    var body: some View {
        HStack(alignment: .top) {
            if let image = technology.image {
                KFImage(image)
                    .resizable()
                    .frame(width: 50, height: 50)
            }
            VStack(alignment: .leading) {
                Text(technology.title)
                    .font(.headline)
                if let subtitle = technology.subtitle {
                    Text(subtitle)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var documentationViewModel: DocumentationViewModel =
        .init()
    AddTechnologyView()
        .environment(documentationViewModel)
        .modelContainer(for: [DocCSite.self], isAutosaveEnabled: true)
}
