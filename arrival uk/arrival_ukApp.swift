//
//  arrival_ukApp.swift
//  arrival uk
//
//  Created by Abdul Hannan on 2/3/26.
//

import SwiftUI

@main
struct arrival_ukApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(ArrivalAppDelegateBridge.self) private var appDelegate
    #endif

    init() {
        CrashReporter.bootstrapIfNeeded()
        AppConfig.validateRequiredConfiguration()
        ConfigService.shared.configureIfNeeded()
        PerformanceMonitor.shared.bootstrapIfNeeded()
        if #available(iOS 17.0, *) {
            PushNotificationManager.shared.configureIfNeeded()
            ContextualLocationTriggerManager.shared.configureIfNeeded()
            TaskSyncStore.shared.configureIfNeeded()
            LowPowerModeManager.shared.configureIfNeeded()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }

        WindowGroup("Pinned Document", id: ArrivalContinuity.pinnedDocumentSceneID) {
            PinnedDocumentWindowView()
                .onContinueUserActivity(ArrivalContinuity.openDocumentActivityType) { activity in
                    guard let documentID = ArrivalWindowSceneBridge.documentID(from: activity) else { return }
                    ArrivalWindowSceneBridge.stagePinnedDocumentID(documentID)
                }
        }
        .handlesExternalEvents(matching: [ArrivalContinuity.openDocumentActivityType])
    }
}
