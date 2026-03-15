import Foundation

/// Typed storage keys for `UserDefaults` / encrypted defaults / keychain key IDs.
/// Keeping keys centralized prevents silent data loss from drift across call sites.
enum StorageKey: String {
    case contentProgressV2Encrypted = "content.store.progress.v2.encrypted"
    case contentProgressV1Legacy = "content.store.progress.v1"
    case contentProgressEncryptionKey = "content.store.progress.encryption.key"

    case homeCompletionStreakEncrypted = "home.completionStreak.encrypted"
    case homeCompletionStreakEncryptionKey = "home.completionStreak.encryption.key"
    case homeCompletionStreakLegacy = "home.completionStreak"
    case homeCompletionStreakLastActiveLegacy = "home.completionStreak.lastActiveDate"
    case homeCompletedSectionCollapsed = "home.completedSectionCollapsed"
    case homeSponsoredSlotEnabled = "home.sponsoredSlotEnabled"
    case homeHasLaunchedBefore = "home.hasLaunchedBefore"
    case homeIsSettledMode = "home.isSettledMode"

    case notificationsDailyHour = "notifications.daily.hour"
    case notificationsDailyMinute = "notifications.daily.minute"
    case notificationsCriticalLastTaskID = "notifications.critical.lastTaskID"
    case notificationsCriticalLastSentAt = "notifications.critical.lastSentAt"
    case notificationsCollaborativeUrgentLastTaskID = "notifications.collabUrgent.lastTaskID"
    case notificationsCollaborativeUrgentLastSentAt = "notifications.collabUrgent.lastSentAt"

    case pushInstallationID = "push.installation.id.v1"
    case pushPendingFCMToken = "push.pending.fcm.token.v1"
    case supportLatestTicketIDPrefix = "support.latestTicketId."

    case studentProfileV2Encrypted = "student.profile.v2.encrypted"
    case studentProfileV1Legacy = "student.profile.v1"
    case studentProfileEncryptionKey = "student.profile.encryption.key"
    case studentAuthToken = "student.auth.token"
    case studentAuthRefreshToken = "student.auth.refresh"

    case walletDocumentsSecure = "wallet.documents.secure.v1"
    case taskSyncLastOpenedTaskID = "tasks.sync.lastOpenedTaskID"
    case taskSyncLastOpenedCategoryID = "tasks.sync.lastOpenedCategoryID"
    case collaborationActorID = "collaboration.actor.id.v1"
    case collaborationLamportCounter = "collaboration.lamport.counter.v1"
    case collaborationTaskSet = "collaboration.taskset.v1"
    case collaborationJourneyID = "collaboration.journey.id.v1"
    case collaborationPresenceHeartbeat = "collaboration.presence.heartbeat.v1"
    case sharedDiscoveryBoard = "discovery.shared.board.v1"
    case walletShareSigningKey = "wallet.share.signing.key.v1"
    case marketplaceIdentitySigningKey = "marketplace.identity.signing.key.v1"
    case remoteConfigCache = "config.remote.payload.v1"
    case remoteConfigUpdatedAt = "config.remote.updatedAt.v1"
    case phase15RegionRegistry = "phase15.region.registry.v1"
    case phase15ActiveRegion = "phase15.region.active.v1"
    case telemetryEventsCache = "telemetry.events.cache.v1"
    case crashSessionInProgress = "crash.session.inProgress.v1"
    case crashLastUncleanAt = "crash.lastUnclean.at.v1"

    case adsWantsPersonalized = "ads.wantsPersonalizedAds"
    case adsTrackingAuthorizationState = "ads.trackingAuthorizationState"
    case adsHasAcceptedDisclosure = "ads.hasAcceptedDisclosure"
}
