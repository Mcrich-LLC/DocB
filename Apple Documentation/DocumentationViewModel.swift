//
//  DocumentationViewModel.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/6/24.
//

import Foundation

class DocumentationViewModel: ObservableObject {
    
    // MARK: Technologies
    private let technologiesUrl = URL(string: "https://developer.apple.com/tutorials/data/documentation/technologies.json")!
    
    @Published var technologies: Technologies?
    
    func fetchTechnologies() async {
        do {
            let (data, response) = try await URLSession.shared.data(from: technologiesUrl)
            
            let technologies = try JSONDecoder().decode(Technologies.self, from: data)
            self.technologies = technologies
        } catch {
            print(error)
        }
    }
    
    // MARK: Frameworks
    
    @Published var frameworks: [String : Framework] = [:]
    
    private func frameworkUrl(for identifier: String) -> URL? {
        guard let identifier = URL(string: identifier) else {
            return nil
        }
        
        let path = identifier.path + ".json"
        
        let url = Constants.basePath.appending(path: path)
        
        return url
    }
    
    func fetchFramework(for identifier: String) async {
        do {
            guard let url = frameworkUrl(for: identifier) else { return }
            
            let (data, response) = try await URLSession.shared.data(from: url)
            
            let framework = try JSONDecoder().decode(Framework.self, from: data)
            self.frameworks[identifier] = framework
        } catch {
            print(error)
        }
    }
}
