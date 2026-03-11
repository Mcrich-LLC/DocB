//
//  DocumentationViewModel.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/6/24.
//

import Foundation
import SwiftUI
import SwiftData

enum PreferedProgrammingLanguage: String, Codable, CaseIterable {
    case swift
    case objectivec = "objc"
    case data
    
    var humanReadable: String? {
        switch self {
        case .swift:
            "Swift"
        case .objectivec:
            "Objective-C"
        case .data:
            nil
        }
    }
    
    var jsonCodingValue: String {
        switch self {
        case .swift:
            "swift"
        case .objectivec:
            "occ"
        case .data:
            "data"
        }
    }
    
    init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "swift":
            self = .swift
        case "objc", "occ":
            self = .objectivec
        case "data":
            self = .data
        default:
            return nil
        }
    }
}

@Observable
@MainActor
class DocumentationViewModel {
    var preferedProgrammingLanguage: PreferedProgrammingLanguage = UserDefaults.standard.string(forKey: "preferedProgrammingLanguage").flatMap(PreferedProgrammingLanguage.init(rawValue:)) ?? .swift {
        didSet {
            UserDefaults.standard.set(preferedProgrammingLanguage.rawValue, forKey: "preferedProgrammingLanguage")
        }
    }
    
    // MARK: URL Functions
    func jsonUrl(for identifier: String, site: DocCSiteDTO?) -> URL? {
        if let site {
            var identifier: String = identifier.lowercased()
            if let index = identifier.firstRange(of: "/documentation") {
                identifier = identifier.suffix(from: index.lowerBound).lowercased()
            }
            
            let url = site.url
                .appending(path: "data")
                .appending(path: identifier)
                .appendingPathExtension("json")
            
            return url
        }
        
        guard let identifier = URL(string: identifier) else {
            return nil
        }
        
        let queryItems: [URLQueryItem] = [
            .init(name: "language", value: preferedProgrammingLanguage.rawValue)
        ]
        
        let url = Constants.basePath.appending(path: identifier.path)
            .appendingPathExtension("json")
            .appending(queryItems: queryItems)
        
        return url
    }
    
    func getRedirectedURL(for url: URL) async throws -> URL {
        let (_, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, let url = httpResponse.url else {
            throw URLError(.badServerResponse)
        }
        
        return url
    }
    
    // MARK: Homepage
    private let homepageUrl = URL(string: "\(Constants.aDeveloperURLBase)/tutorials/data/documentation.json")!
    var homepage: HomepageParser?
    
    private func fetchHomepage() async {
        do {
            let (data, _) = try await URLSession.shared.data(from: homepageUrl)
            
            let homepage = try JSONDecoder().decode(HomepageParser.self, from: data)
            await MainActor.run {
                self.homepage = homepage
            }
        } catch {
            print(error)
        }
    }
    
    // MARK: Technologies
    private let technologiesUrl = URL(string: "\(Constants.aDeveloperURLBase)/tutorials/data/documentation/technologies.json")!
    
    private(set) var technologies: [TechnologyTypes] = []
    private(set) var appleDocCSiteRef: DocCSiteDTO?
    
    private func fetchTechnologies() async {
        do {
            let (data, _) = try await URLSession.shared.data(from: technologiesUrl)
            
            let technologies = try JSONDecoder().decode(AppleTechnologies.self, from: data)
            await MainActor.run {
                self.technologies.append(.apple(technologies))
            }
        } catch {
            print(error)
        }
    }
    
    func addTechnology(baseUrl: URL, modelContext: ModelContext, overrideName: String? = nil) async throws {
        guard !baseUrl.absoluteString.contains("developer.apple.com") else {
            let site = DocCSite(url: baseUrl, index: .init(interfaceLanguages: [:]))
            modelContext.insert(site)
            try modelContext.save()
            await fetchHomepage()
            await fetchTechnologies()
            return
        }
        do {
            guard !technologies.contains(where: { tech in
                switch tech {
                case .apple:
                    return false
                case .docC(let docCSiteDTO):
                    return docCSiteDTO.url == baseUrl
                }
            }) else {
                return
            }
            let indexUrl = baseUrl.appending(path: "index/index.json")
            let (data, _) = try await URLSession.shared.data(from: indexUrl)
            
            let index = try JSONDecoder().decode(DocCIndex.self, from: data)
            let site = DocCSite(url: baseUrl, overrideName: overrideName, index: index)
            modelContext.insert(site)
            try modelContext.save()
            let dto = try site.dto
            await MainActor.run {
                withAnimation {
                    self.technologies.append(.docC(dto))
                }
            }
        } catch {
            print(error)
        }
    }
    
    func loadTechnologies(_ sites: [DocCSiteDTO]) async {
        for site in sites {
            guard !site.url.absoluteString.contains("developer.apple.com") else {
                appleDocCSiteRef = site
                await fetchHomepage()
                await fetchTechnologies()
                continue
            }
            do {
                let indexUrl = site.url.appending(path: "index/index.json")
                let (data, _) = try await URLSession.shared.data(from: indexUrl)
                
                let index = try JSONDecoder().decode(DocCIndex.self, from: data)
                site.setIndex(index)
                await MainActor.run {
                    withAnimation {
                        self.technologies.append(.docC(site))
                    }
                }
            } catch {
                print(error)
            }
        }
    }
    
    func deleteTechnology(_ site: TechnologyTypes, modelContext: ModelContext) throws {
        switch site {
        case .apple:
            technologies.removeAll { $0.id == site.id }
            if let site = appleDocCSiteRef {
                try site.deleteSite(modelContext: modelContext)
            }
        case .docC(let docCSiteDTO):
            technologies.removeAll { $0.id == site.id }
            try docCSiteDTO.deleteSite(modelContext: modelContext)
        }
    }
    
    // MARK: Frameworks
    
    var frameworks: [String : Framework] = [:]
    
    func fetchFramework(for identifier: String, site: DocCSiteDTO?, completion: @escaping () -> Void) {
        Task {
            await fetchFramework(for: identifier, site: site)
            completion()
        }
    }
    
    func fetchFramework(for identifier: String, site: DocCSiteDTO?) async {
        do {
            guard let url = jsonUrl(for: identifier, site: site) else { return }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            
            let framework = try JSONDecoder().decode(Framework.self, from: data)
            
            await MainActor.run {
                self.frameworks[identifier] = framework
            }
        } catch {
            print(error)
        }
    }
    
    // MARK: Articles
    
    func fetchArticle(for identifier: String, site: DocCSiteDTO?, completion: @escaping (Article) -> Void) {
        Task {
            do {
                let article = try await fetchArticle(for: identifier, site: site)
                completion(article)
            } catch {
                print(error)
            }
        }
    }
    
    func fetchArticle(for identifier: String, site: DocCSiteDTO?) async throws -> Article {
//        do {
        guard let url = jsonUrl(for: identifier, site: site) else { throw URLError(.badURL) }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        var article = try JSONDecoder().decode(Article.self, from: data)
        
        for variant in (article.variantOverrides ?? []) where variant.patch.contains(where: {
            ($0.value?.declarations ?? []).contains(where: {
                $0.languages.contains(preferedProgrammingLanguage.jsonCodingValue)
            })
        }) {
            for patch in variant.patch where (patch.value?.declarations ?? []).contains(where: { $0.languages.contains(preferedProgrammingLanguage.jsonCodingValue) }) {
                let pathComponents = patch.path.split(separator: "/")
                // Handle primaryContentSections
                if pathComponents.contains(where: { $0 == "primaryContentSections" }), let indexString = pathComponents.last, let index = Int(indexString) {
                    article.primaryContentSections?[index].declarations = patch.value?.declarations
                }
            }
        }
        
        return article
//        } catch {
//            print(error)
//        }
    }
}
