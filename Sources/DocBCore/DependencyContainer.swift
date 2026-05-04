//
//  DependencyContainer.swift
//  DocBCore
//
//  Created by OpenAI on 5/4/26.
//

import FactoryKit
import Foundation
import SwiftData

/// Factory registrations for DocB's app-level services.
public extension Container {
    /// Shared SwiftData container for documentation sources, bookmarks, and bookmark collections.
    var docBModelContainer: Factory<ModelContainer> {
        self {
            do {
                return try ModelContainer(
                    for: DocCSite.self,
                    Bookmark.self,
                    BookmarkCollection.self,
                    configurations: .init(cloudKitDatabase: .none)
                )
            } catch {
                fatalError("Error Initializing ModelContainer: \(error)")
            }
        }
        .singleton
    }
    
    /// Shared documentation browsing model used by app scenes.
    var documentationViewModel: Factory<DocumentationViewModel> {
        self { DocumentationViewModel() }
            .singleton
    }
    
    /// Shared app settings model used by app scenes.
    @MainActor
    var appSettings: Factory<AppSettings> {
        self { @MainActor in AppSettings() }
            .singleton
    }
    
    /// Required CloudKit container identifier supplied by the app target's Info.plist.
    var docBCloudKitContainerIdentifier: Factory<String> {
        self {
            guard let rawValue = Bundle.main.infoDictionary?["CLOUDKIT_ID"] as? String else {
                fatalError("Missing CLOUDKIT_ID in Info.plist.")
            }
            
            let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, value != "$(CLOUDKIT_ID)" else {
                fatalError("Invalid CLOUDKIT_ID in Info.plist: \(rawValue)")
            }
            
            return value
        }
        .singleton
    }
    
    /// Shared explicit CloudKit sync coordinator backed by MYCloudKit.
    var docBCloudSyncEngine: Factory<DocBCloudSyncEngine> {
        self {
            DocBCloudSyncEngine(
                modelContainer: self.docBModelContainer(),
                containerIdentifier: self.docBCloudKitContainerIdentifier()
            )
        }
        .singleton
    }
}
