import Foundation
import SwiftUI

extension ContentView {
    @MainActor
    func processIncomingURL(_ url: URL) {
        _ = handleOpenURL(url)
    }

    @MainActor
    func consumePendingIntentRouteIfNeeded() {
        guard let pendingURL = ArrivalIntentRouteBridge.consumePendingDeepLinkURL() else { return }
        _ = handleOpenURL(pendingURL)
    }

    @MainActor
    func handleContinuedTaskGuideActivity(_ activity: NSUserActivity) {
        guard let userInfo = activity.userInfo else { return }
        let taskID = (userInfo[ArrivalContinuity.taskIDKey] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let categoryID = (userInfo[ArrivalContinuity.categoryIDKey] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !taskID.isEmpty else { return }
        _ = openTaskGuide(taskID: taskID, preferredCategoryID: categoryID.isEmpty ? nil : categoryID)
    }

    @MainActor
    func handleContinuedOpenDocumentActivity(_ activity: NSUserActivity) {
        guard let documentID = ArrivalWindowSceneBridge.documentID(from: activity) else { return }
        ArrivalWindowSceneBridge.stagePinnedDocumentID(documentID)
        openWalletFromWidgetRoute(shouldUnlock: false)
        walletManager.focusDocument(id: documentID)
    }

    @MainActor
    func handleNotificationTap(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }

        if let deepLink = userInfo["deepLink"] as? String,
           let url = URL(string: deepLink) {
            processIncomingURL(url)
            return
        }

        if let deepLinkURL = userInfo["deepLink"] as? URL {
            processIncomingURL(deepLinkURL)
        }
    }

    @MainActor
    func handleMarketplaceCompletion(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        let taskID = (userInfo["taskID"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !taskID.isEmpty else { return }
        markTaskCompleteFromDetail(taskID: taskID)
    }

    @MainActor
    func handleOpenURL(_ url: URL) -> OpenURLAction.Result {
        if GoogleSignInBridge.handle(url: url) {
            return .handled
        }

        if handleWidgetRoute(url) {
            return .handled
        }

        if let provider = marketplaceCoordinator.resolveProviderFromUniversalLink(
            url,
            config: configService.current
        ) {
            Task { @MainActor in
                await launchMarketplaceService(provider, entryPoint: "universal_link")
            }
            return .handled
        }

        guard ContentExternalURLRoute.resolve(for: url) == .presentInApp else {
            let host = url.host ?? "unknown-host"
            let scheme = url.scheme ?? "unknown-scheme"
            CrashReporter.log("blocked external URL scheme=\(scheme) host=\(host)", level: .warning)
            return .discarded
        }
        registerAdEvent(.resourceOpened)
        Motion.mutate {
            activeWebURL = url
        }
        return .handled
    }

    @MainActor
    func launchMarketplaceService(
        _ descriptor: MarketplaceProviderDescriptor,
        entryPoint: String
    ) async {
        let result = await marketplaceCoordinator.launchService(
            descriptor: descriptor,
            walletManager: walletManager,
            identityTokenTTLSeconds: TimeInterval(configService.current.phase14Marketplace.identityTokenTTLSeconds),
            entryPoint: entryPoint
        )

        guard let result else {
            showToast(marketplaceCoordinator.lastErrorMessage ?? "Could not launch provider.")
            return
        }

        guard let launchURL = MarketplaceLaunchURLResolver.resolve(
            primary: result.deepLinkURL,
            fallback: descriptor.onboardingURL
        ) else {
            CrashReporter.log(
                "marketplace_launch_blocked provider=\(descriptor.normalizedProviderID)",
                level: .warning
            )
            showToast("Could not open provider.")
            return
        }

        presentSheet(.web(launchURL))
        showToast("\(descriptor.displayName) started.")
    }

    @MainActor
    func handleWidgetRoute(_ url: URL) -> Bool {
        guard let route = ArrivalWidgetRoute(url: url) else {
            return false
        }

        switch route {
        case .task(let target):
            guard target.isComplete else {
                return true
            }

            if openTaskFromWidgetRoute(categoryID: target.categoryID, taskID: target.taskID) {
                return true
            }

            pendingWidgetRoute = target
            return true
        case .wallet(let target):
            openWalletFromWidgetRoute(
                shouldUnlock: target.shouldUnlock,
                preferredDocumentType: target.documentType
            )
            return true
        case .quickTask:
            return openQuickTaskFromRoute()
        case .discountQR:
            closeCategoryDetail()
            dismissActiveModal()
            isProfileSheetPresented = false
            presentSheet(.scanQR)
            return true
        }
    }

    @MainActor
    func consumePendingWidgetRouteIfPossible() {
        guard let pendingWidgetRoute else { return }
        if openTaskFromWidgetRoute(categoryID: pendingWidgetRoute.categoryID, taskID: pendingWidgetRoute.taskID) {
            self.pendingWidgetRoute = nil
        }
    }

    @MainActor
    func openTaskFromWidgetRoute(categoryID: String, taskID: String) -> Bool {
        guard let categoryIndex = store.categories.firstIndex(where: { $0.id == categoryID }) else {
            return false
        }

        guard store.categories[categoryIndex].tasks.contains(where: { $0.id == taskID }) else {
            return false
        }

        return openTaskGuide(taskID: taskID, preferredCategoryID: categoryID)
    }

    @MainActor
    func openWalletFromWidgetRoute(
        shouldUnlock: Bool,
        preferredDocumentType: SecureDocType? = nil
    ) {
        closeCategoryDetail()
        dismissActiveModal()
        isProfileSheetPresented = false
        pendingHomeScrollAnchorID = HomeScrollAnchor.walletSection
        if let preferredDocumentType {
            walletManager.focusDocumentType(preferredDocumentType)
        }

        if shouldUnlock {
            walletManager.requestAccess()
        }
    }

    @MainActor
    func openQuickTaskFromRoute() -> Bool {
        if let snapshot = ArrivalWidgetSupport.latestSnapshot(),
           !snapshot.categoryID.isEmpty,
           !snapshot.taskID.isEmpty,
           openTaskFromWidgetRoute(categoryID: snapshot.categoryID, taskID: snapshot.taskID) {
            return true
        }

        if let next = taskEngine.survivalQueue.first {
            return openTaskGuide(taskID: next.taskID, preferredCategoryID: next.categoryID)
        }
        if let next = taskEngine.maintenanceTasks.first {
            return openTaskGuide(taskID: next.taskID, preferredCategoryID: next.categoryID)
        }

        showToast("No pending priority task found.")
        return true
    }
}
