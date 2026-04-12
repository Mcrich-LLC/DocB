//
//  IsCoreDataSyncingModifier.swift
//  DocBCore
//
//  Created by Morris Richman on 4/12/26.
//

import SwiftUI
import CoreData

/// A modifier that leverages several notifications to tell a bound variable if CoreData is syncing with CloudKit.
private struct CoreDataIsSyncingModifier: ViewModifier {
    /// Tracks if `NSPersistentCloudKitContainer.eventChangedNotification` has pushed a import ended notification.
    ///
    /// This is useful for when `NSPersistentStoreRemoteChange` is being tracked.
    @State private var hasImported: Bool = false
    
    /// The externally exposed boolean variable describing how the sync state.
    @Binding var isSyncing: Bool
    
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange).receive(on: DispatchQueue.main)) { _ in
                if !hasImported {
                    isSyncing = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(
                for: NSPersistentCloudKitContainer.eventChangedNotification
            ).receive(on: DispatchQueue.main)) { notification in
                guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                        as? NSPersistentCloudKitContainer.Event else {
                    return
                }

                switch event.type {
                case .setup:
                    print("CloudKit setup started")
                case .import:
                    if event.endDate == nil {
                        print("CloudKit Import (download) started")
                        isSyncing = true
                    } else {
                        print("CloudKit Import (download) ended")
                        isSyncing = false
                        hasImported = true
                    }
                case .export:
                    if event.endDate == nil {
                        print("CloudKit Export (upload) started")
                    } else {
                        print("CloudKit Export (upload) ended")
                    }
                @unknown default:
                    break
                }
            }
    }
}

extension View {
    /// A modifier that leverages several notifications to tell a bound variable if CoreData is syncing with CloudKit.
    public func isCoreDataSyncing(_ isSyncing: Binding<Bool>) -> some View {
        modifier(CoreDataIsSyncingModifier(isSyncing: isSyncing))
    }
}
