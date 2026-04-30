//
//  DocBCloudSyncEngine.swift
//  DocBCore
//
//  Created by OpenAI on 4/29/26.
//

import Combine
import DocCKit
import Foundation
import MYCloudKit
import Observation
import SwiftData
import SwiftUI

/// Coordinates DocB's explicit CloudKit sync without allowing SwiftData to opt into Core Data mirroring.
///
/// SwiftData remains the local persistence layer. CloudKit writes, fetches, retries, and deletes are routed through
/// `MYSyncEngine`, while this coordinator bridges fetched CloudKit records back into SwiftData models.
@Observable
public final class DocBCloudSyncEngine: MYSyncDelegate {
    /// Whether MYCloudKit is currently uploading, downloading, or applying remote changes locally.
    public private(set) var isSyncing = false
    
    /// Whether fetched CloudKit records are currently being applied to SwiftData.
    public private(set) var isApplyingRemoteChanges = false
    
    @ObservationIgnored private let modelContainer: ModelContainer
    @ObservationIgnored private let syncEngine: MYSyncEngine
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []
    @ObservationIgnored private var isUploading = false
    @ObservationIgnored private var isFetching = false
    @ObservationIgnored private var recentlyImportedRecordKeys: Set<String> = []
    @ObservationIgnored private var syncedRecordSignatures: [String: String] = [:]
    @ObservationIgnored private var rootGroupDeleteIDs: Set<String> = []
    
    /// Creates the CloudKit sync coordinator for a SwiftData container.
    ///
    /// - Parameters:
    ///   - modelContainer: SwiftData container used for local persistence.
    ///   - containerIdentifier: Optional CloudKit container identifier backed by the active target entitlements.
    public init(
        modelContainer: ModelContainer,
        containerIdentifier: String? = nil
    ) {
        self.modelContainer = modelContainer
        self.syncEngine = MYSyncEngine(containerIdentifier: containerIdentifier)
        self.syncEngine.delegate = self
        observeSyncEngineState()
    }
    
    /// Starts the CloudKit fetch-and-upload loop for the current launch.
    @MainActor
    public func start() async {
        await fetchRemoteChanges()
    }
    
    /// Fetches remote CloudKit changes and resumes any pending local upload queue.
    @MainActor
    public func fetchRemoteChanges() async {
        await syncEngine.beginFetch()
        syncEngine.beginSync()
    }
    
    /// Records the currently loaded syncable SwiftData state as the local baseline.
    ///
    /// - Parameters:
    ///   - docCSites: Persisted documentation sites.
    ///   - collections: Bookmark collections.
    ///   - bookmarks: Saved bookmarks.
    public func syncAll(
        docCSites: [DocCSite],
        collections: [BookmarkCollection],
        bookmarks: [Bookmark]
    ) {
        guard !isApplyingRemoteChanges else { return }
        
        collections.forEach { rememberSyncedState($0) }
        bookmarks.forEach { rememberSyncedState($0) }
        docCSites.forEach { rememberSyncedState($0) }
    }
    
    /// Queues sync and delete operations for DocC site changes observed through SwiftData.
    ///
    /// - Parameters:
    ///   - oldValue: Previous SwiftData query result.
    ///   - newValue: Current SwiftData query result.
    public func syncDocCSiteChanges(oldValue: [DocCSite], newValue: [DocCSite]) {
        syncChanges(oldValue: oldValue, newValue: newValue)
    }
    
    /// Queues sync and delete operations for bookmark collection changes observed through SwiftData.
    ///
    /// - Parameters:
    ///   - oldValue: Previous SwiftData query result.
    ///   - newValue: Current SwiftData query result.
    public func syncBookmarkCollectionChanges(oldValue: [BookmarkCollection], newValue: [BookmarkCollection]) {
        syncChanges(oldValue: oldValue, newValue: newValue)
    }
    
    /// Queues sync and delete operations for bookmark changes observed through SwiftData.
    ///
    /// - Parameters:
    ///   - oldValue: Previous SwiftData query result.
    ///   - newValue: Current SwiftData query result.
    public func syncBookmarkChanges(oldValue: [Bookmark], newValue: [Bookmark]) {
        syncChanges(oldValue: oldValue, newValue: newValue)
    }
    
    /// Saves fetched CloudKit records into SwiftData in dependency order.
    ///
    /// - Parameter records: CloudKit records fetched by MYCloudKit.
    /// - Returns: `true` when the records were merged successfully.
    public func didReceiveRecordsToSave(_ records: [MYSyncEngine.FetchedRecord]) async -> Bool {
        setApplyingRemoteChanges(true)
        
        do {
            let context = ModelContext(modelContainer)
            for record in records {
                recentlyImportedRecordKeys.insert(recordKey(type: record.type, id: record.id))
                
                switch record.type {
                case DocBCloudRecordTypes.docCSite:
                    try upsertDocCSite(from: record, in: context)
                case DocBCloudRecordTypes.bookmarkCollection:
                    try upsertBookmarkCollection(from: record, in: context)
                case DocBCloudRecordTypes.bookmark:
                    try upsertBookmark(from: record, in: context)
                default:
                    continue
                }
            }
            
            try reconnectBookmarks(in: context)
            try context.save()
            setApplyingRemoteChanges(false)
            return true
        } catch {
            print("DocB CloudKit import failed: \(error)")
            setApplyingRemoteChanges(false)
            return false
        }
    }
    
    /// Deletes SwiftData records that MYCloudKit reports as removed remotely.
    ///
    /// - Parameter records: Deleted CloudKit record identifiers.
    /// - Returns: `true` when local deletion succeeds.
    public func didReceiveRecordsToDelete(_ records: [(myRecordID: String, myRecordType: MYRecordType)]) async -> Bool {
        setApplyingRemoteChanges(true)
        
        do {
            let context = ModelContext(modelContainer)
            for record in records {
                let key = recordKey(type: record.myRecordType, id: record.myRecordID)
                recentlyImportedRecordKeys.insert(key)
                syncedRecordSignatures.removeValue(forKey: key)
                
                switch record.myRecordType {
                case DocBCloudRecordTypes.docCSite:
                    try deleteDocCSite(idString: record.myRecordID, in: context)
                case DocBCloudRecordTypes.bookmarkCollection:
                    try deleteBookmarks(collectionIDString: record.myRecordID, in: context)
                    try deleteBookmarkCollection(idString: record.myRecordID, in: context)
                    removeSyncedRecords(inGroupID: record.myRecordID)
                    rootGroupDeleteIDs.insert(record.myRecordID)
                case DocBCloudRecordTypes.bookmark:
                    try deleteBookmark(idString: record.myRecordID, in: context)
                default:
                    continue
                }
            }
            
            try context.save()
            setApplyingRemoteChanges(false)
            return true
        } catch {
            print("DocB CloudKit delete import failed: \(error)")
            setApplyingRemoteChanges(false)
            return false
        }
    }
    
    /// Deletes local SwiftData records that belong to removed MYCloudKit record groups.
    ///
    /// - Parameter ids: Root group identifiers reported by MYCloudKit.
    /// - Returns: `true` when local deletion succeeds.
    public func didReceiveGroupIDsToDelete(_ ids: [String]) async -> Bool {
        setApplyingRemoteChanges(true)
        
        do {
            let context = ModelContext(modelContainer)
            for id in ids {
                try deleteBookmarks(collectionIDString: id, in: context)
                try deleteDocCSite(idString: id, in: context)
                try deleteBookmarkCollection(idString: id, in: context)
                removeSyncedRecords(inGroupID: id)
                rootGroupDeleteIDs.insert(id)
            }
            
            try context.save()
            setApplyingRemoteChanges(false)
            return true
        } catch {
            print("DocB CloudKit group delete import failed: \(error)")
            setApplyingRemoteChanges(false)
            return false
        }
    }
    
    /// Handles records MYCloudKit could not upload.
    ///
    /// - Parameters:
    ///   - recordID: CloudKit record identifier.
    ///   - recordType: CloudKit record type.
    ///   - reason: Developer-readable failure reason.
    ///   - error: Underlying CloudKit or networking error.
    /// - Returns: Corrected records to retry, or `nil` to let MYCloudKit skip them.
    public func handleUnsyncableRecord(
        recordID: String,
        recordType: MYRecordType,
        reason: String,
        error: any Error
    ) -> [any MYRecordConvertible]? {
        print("DocB CloudKit skipped \(recordType)/\(recordID): \(reason) \(error)")
        return nil
    }
    
    /// Lists supported CloudKit record types in dependency order.
    ///
    /// - Returns: Record types that MYCloudKit should save from parent to child.
    public func syncableRecordTypesInDependencyOrder() -> [MYRecordType] {
        [
            DocBCloudRecordTypes.docCSite,
            DocBCloudRecordTypes.bookmarkCollection,
            DocBCloudRecordTypes.bookmark
        ]
    }
}

extension DocBCloudSyncEngine {
    
    private func observeSyncEngineState() {
        syncEngine.$syncState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.isUploading = Self.isActive(syncState: state)
                self?.refreshSyncingState()
            }
            .store(in: &cancellables)
        
        syncEngine.$fetchState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.isFetching = Self.isActive(fetchState: state)
                self?.refreshSyncingState()
            }
            .store(in: &cancellables)
    }
    
    private func setApplyingRemoteChanges(_ value: Bool) {
        isApplyingRemoteChanges = value
        refreshSyncingState()
    }
    
    private func refreshSyncingState() {
        isSyncing = isUploading || isFetching || isApplyingRemoteChanges
    }
    
    private func syncChanges<Model>(oldValue: [Model], newValue: [Model]) where Model: Identifiable & MYRecordConvertible, Model.ID == UUID {
        guard !isApplyingRemoteChanges else { return }
        
        let newIDs = Set(newValue.map(\.id))
        let deletedRootGroupIDs = Set(
            oldValue.compactMap { model in
                model.myRecordID == model.myRootGroupID ? model.myRootGroupID : nil
            }.filter { rootID in
                !newValue.contains(where: { $0.myRecordID == rootID })
            }
        )
        
        for model in oldValue where !newIDs.contains(model.id) {
            let key = recordKey(type: model.myRecordType, id: model.myRecordID)
            syncedRecordSignatures.removeValue(forKey: key)
            
            if recentlyImportedRecordKeys.remove(key) != nil {
                continue
            }
            
            if let rootGroupID = model.myRootGroupID,
               rootGroupID != model.myRecordID,
               (deletedRootGroupIDs.contains(rootGroupID) || rootGroupDeleteIDs.contains(rootGroupID)) {
                continue
            }
            
            if model.myRecordID == model.myRootGroupID, let rootGroupID = model.myRootGroupID {
                rootGroupDeleteIDs.insert(rootGroupID)
            }
            syncEngine.delete(model, shouldDeleteChildRecords: model.myRecordID == model.myRootGroupID)
        }
        
        for model in newValue {
            let key = recordKey(type: model.myRecordType, id: model.myRecordID)
            let signature = recordSignature(for: model)
            if model.myRecordID == model.myRootGroupID, let rootGroupID = model.myRootGroupID {
                rootGroupDeleteIDs.remove(rootGroupID)
            }
            if recentlyImportedRecordKeys.remove(key) != nil {
                syncedRecordSignatures[key] = signature
                continue
            }
            guard syncedRecordSignatures[key] != signature else { continue }
            
            syncEngine.sync(model)
            syncedRecordSignatures[key] = signature
        }
    }
    
    private static func isActive(syncState: MYSyncEngine.SyncState) -> Bool {
        if case .syncing = syncState {
            return true
        }
        
        return false
    }
    
    private static func isActive(fetchState: MYSyncEngine.FetchState) -> Bool {
        if case .fetching = fetchState {
            return true
        }
        
        return false
    }
    
    private func recordKey(type: String, id: String) -> String {
        "\(type)/\(id)"
    }
    
    private func upsertDocCSite(from record: MYSyncEngine.FetchedRecord, in context: ModelContext) throws {
        guard let id = UUID(uuidString: record.id),
              let urlString: String = record.value(for: "url"),
              let url = URL(string: urlString) else {
            return
        }
        
        let timestamp: Date = record.value(for: "timestamp") ?? .now
        let overrideName: String? = record.value(for: "overrideName")
        let indexData: Data? = record.value(for: "indexData")
        let index = indexData.flatMap { try? JSONDecoder().decode(DocCIndex.self, from: $0) } ?? DocCIndex(interfaceLanguages: [:])
        let descriptor = FetchDescriptor<DocCSite>(
            predicate: #Predicate { site in
                site.id == id
            }
        )
        let existingSite = try context.fetch(descriptor).first
        let site = existingSite ?? DocCSite(timestamp: timestamp, url: url, overrideName: overrideName, index: index)
        
        site.id = id
        site.timestamp = timestamp
        site.url = url
        site.overrideName = overrideName
        if indexData != nil {
            site.indexV2 = DocCSite.DocCIndexModel(index)
        }
        rememberSyncedState(site)
        
        if existingSite == nil {
            context.insert(site)
        }
    }
    
    private func upsertBookmarkCollection(from record: MYSyncEngine.FetchedRecord, in context: ModelContext) throws {
        guard let id = UUID(uuidString: record.id),
              let title: String = record.value(for: "title") else {
            return
        }
        
        let sfSymbolName: String = record.value(for: "sfSymbolName") ?? "folder"
        let lastUpdatedDate: Date = record.value(for: "lastUpdatedDate") ?? .now
        let colorData: Data? = record.value(for: "colorComponents")
        let colorComponents = colorData.flatMap { try? JSONDecoder().decode(ColorComponents.self, from: $0) } ?? Color.accentColor.components()
        let descriptor = FetchDescriptor<BookmarkCollection>(
            predicate: #Predicate { collection in
                collection.id == id
            }
        )
        let existingCollection = try context.fetch(descriptor).first
        let collection = existingCollection ?? BookmarkCollection(
            title: title,
            sfSymbolName: sfSymbolName,
            color: colorComponents.toColor(),
            bookmarks: [],
            lastUpdatedDate: lastUpdatedDate
        )
        
        collection.id = id
        collection.title = title
        collection.sfSymbolName = sfSymbolName
        collection.color = colorComponents.toColor()
        collection.lastUpdatedDate = lastUpdatedDate
        rememberSyncedState(collection)
        
        if existingCollection == nil {
            context.insert(collection)
        }
    }
    
    private func upsertBookmark(from record: MYSyncEngine.FetchedRecord, in context: ModelContext) throws {
        guard let id = UUID(uuidString: record.id),
              let identifier: String = record.value(for: "identifier"),
              let type: String = record.value(for: "type") else {
            return
        }
        
        let title: String? = record.value(for: "title")
        let kind: String? = record.value(for: "kind")
        let roleRawValue: String? = record.value(for: "role")
        let role = roleRawValue.flatMap(Role.init(rawValue:))
        let deprecated: Bool? = record.value(for: "deprecated")
        let beta: Bool? = record.value(for: "beta")
        let siteBaseURLString: String? = record.value(for: "siteBaseURL")
        let siteBaseURL = siteBaseURLString.flatMap(URL.init(string:))
        let collectionIDString: String? = record.value(for: "collectionID")
        let collectionReferenceIDString: String? = record.value(for: "collection")
        let collectionID = (collectionIDString ?? collectionReferenceIDString).flatMap(UUID.init(uuidString:))
        let descriptor = FetchDescriptor<Bookmark>(
            predicate: #Predicate { bookmark in
                bookmark.id == id
            }
        )
        let existingBookmark = try context.fetch(descriptor).first
        let bookmark = existingBookmark ?? Bookmark(
            title: title,
            identifier: identifier,
            kind: kind,
            type: type,
            role: role,
            deprecated: deprecated,
            beta: beta,
            siteBaseURL: siteBaseURL
        )
        
        bookmark.id = id
        bookmark.title = title
        bookmark.identifier = identifier
        bookmark.kind = kind
        bookmark.type = type
        bookmark.role = role
        bookmark.deprecated = deprecated
        bookmark.beta = beta
        bookmark.siteBaseURL = siteBaseURL
        bookmark.collectionID = collectionID
        
        if let collectionID,
           let collection = try fetchBookmarkCollection(id: collectionID, in: context) {
            bookmark.collection = collection
        } else if collectionID == nil || bookmark.collection?.id != collectionID {
            bookmark.collection = nil
        }
        rememberSyncedState(bookmark)
        
        if existingBookmark == nil {
            context.insert(bookmark)
        }
    }
    
    func reconnectBookmarks(in context: ModelContext) throws {
        let descriptor = FetchDescriptor<Bookmark>()
        for bookmark in try context.fetch(descriptor) {
            guard let collectionID = bookmark.collectionID,
                  bookmark.collection?.id != collectionID,
                  let collection = try fetchBookmarkCollection(id: collectionID, in: context) else {
                continue
            }
            
            bookmark.collection = collection
            rememberSyncedState(bookmark)
        }
    }
    
    private func fetchBookmarkCollection(id: UUID, in context: ModelContext) throws -> BookmarkCollection? {
        let descriptor = FetchDescriptor<BookmarkCollection>(
            predicate: #Predicate { collection in
                collection.id == id
            }
        )
        
        return try context.fetch(descriptor).first
    }
    
    private func deleteDocCSite(idString: String, in context: ModelContext) throws {
        guard let id = UUID(uuidString: idString) else { return }
        let descriptor = FetchDescriptor<DocCSite>(
            predicate: #Predicate { site in
                site.id == id
            }
        )
        
        for site in try context.fetch(descriptor) {
            context.delete(site)
        }
    }
    
    private func deleteBookmarkCollection(idString: String, in context: ModelContext) throws {
        guard let id = UUID(uuidString: idString) else { return }
        let descriptor = FetchDescriptor<BookmarkCollection>(
            predicate: #Predicate { collection in
                collection.id == id
            }
        )
        
        for collection in try context.fetch(descriptor) {
            context.delete(collection)
        }
    }
    
    private func deleteBookmarks(collectionIDString: String, in context: ModelContext) throws {
        guard let collectionID = UUID(uuidString: collectionIDString) else { return }
        let descriptor = FetchDescriptor<Bookmark>(
            predicate: #Predicate { bookmark in
                bookmark.collectionID == collectionID || bookmark.collection?.id == collectionID
            }
        )
        
        for bookmark in try context.fetch(descriptor) {
            context.delete(bookmark)
        }
    }
    
    private func deleteBookmark(idString: String, in context: ModelContext) throws {
        guard let id = UUID(uuidString: idString) else { return }
        let descriptor = FetchDescriptor<Bookmark>(
            predicate: #Predicate { bookmark in
                bookmark.id == id
            }
        )
        
        for bookmark in try context.fetch(descriptor) {
            context.delete(bookmark)
        }
    }
    
    private func rememberSyncedState(_ record: any MYRecordConvertible) {
        syncedRecordSignatures[recordKey(type: record.myRecordType, id: record.myRecordID)] = recordSignature(for: record)
    }
    
    private func removeSyncedRecords(inGroupID groupID: String) {
        syncedRecordSignatures = syncedRecordSignatures.filter { _, signature in
            !signature.contains("|root=\(groupID)|")
        }
    }
    
    private func recordSignature(for record: any MYRecordConvertible) -> String {
        let properties = record.myProperties
            .map { "\($0.key)=\(signature(for: $0.value))" }
            .sorted()
            .joined(separator: "|")
        
        return "\(record.myRecordType)|\(record.myRecordID)|root=\(record.myRootGroupID ?? "")|parent=\(record.myParentID ?? "")|\(properties)"
    }
    
    private func signature(for value: MYRecordValue) -> String {
        switch value {
        case .int(let value):
            return "int:\(value.map { String($0) } ?? "nil")"
        case .double(let value):
            return "double:\(value.map { String($0) } ?? "nil")"
        case .float(let value):
            return "float:\(value.map { String($0) } ?? "nil")"
        case .bool(let value):
            return "bool:\(value.map { String($0) } ?? "nil")"
        case .date(let value):
            return "date:\(value?.timeIntervalSinceReferenceDate.description ?? "nil")"
        case .asset(let data):
            return "asset:\(data?.base64EncodedString() ?? "nil")"
        case .fileURL(let url):
            return "fileURL:\(url?.absoluteString ?? "nil")"
        case .string(let value):
            return "string:\(value ?? "nil")"
        case .reference(let record, let deleteRule):
            return "reference:\(record?.myRecordType ?? "nil")/\(record?.myRecordID ?? "nil")/\(record?.myRootGroupID ?? "nil")/\(deleteRule)"
        case .array(let values):
            return "array:[\(values.map { signature(for: $0) }.joined(separator: ","))]"
        case .codable(let value):
            return "codable:\(value.map { String(describing: $0) } ?? "nil")"
        }
    }
}

/// CloudKit record type names used by DocB's MYCloudKit integration.
public enum DocBCloudRecordTypes {
    /// Persisted DocC source record type.
    public static let docCSite = "DocCSite"
    /// Bookmark collection record type.
    public static let bookmarkCollection = "BookmarkCollection"
    /// Bookmark record type.
    public static let bookmark = "Bookmark"
}

extension Notification.Name {
    /// Posted by app targets when CloudKit reports a remote change notification.
    public static let docBCloudKitRemoteNotificationReceived = Notification.Name("DocBCloudKitRemoteNotificationReceived")
}
