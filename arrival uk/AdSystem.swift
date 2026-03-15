import Foundation
import UIKit
import os
#if canImport(AppTrackingTransparency)
import AppTrackingTransparency
#endif

enum AdTopic: String, CaseIterable {
    case education
    case finance
    case transport
    case housing
    case groceries
    case career
    case gambling
    case betting
    case adult
    case dating
    case alcohol
    case tobacco
}

enum AdContentRules {
    static let blockedTopics: Set<AdTopic> = [
        .gambling,
        .betting,
        .adult,
        .dating,
        .alcohol,
        .tobacco
    ]

    static let defaultSafeTopics: Set<AdTopic> = [
        .education,
        .finance,
        .transport,
        .housing,
        .groceries,
        .career
    ]

    static let blockedCategorySummary = "Gambling, betting, adult, dating, alcohol, and tobacco."

    static func allows(topics: Set<AdTopic>) -> Bool {
        !topics.isEmpty && topics.isDisjoint(with: blockedTopics)
    }
}

enum AdEvent: String {
    case appBecameActive = "app_became_active"
    case taskToggled = "task_toggled"
    case taskDetailOpened = "task_detail_opened"
    case personalTaskAdded = "personal_task_added"
    case resourceOpened = "resource_opened"
    case sponsoredSlotImpression = "sponsored_slot_impression"
    case sponsoredSlotTapped = "sponsored_slot_tapped"

    var countsAsInteraction: Bool {
        switch self {
        case .taskToggled, .taskDetailOpened, .personalTaskAdded, .resourceOpened, .sponsoredSlotTapped:
            return true
        case .appBecameActive, .sponsoredSlotImpression:
            return false
        }
    }

    var canTriggerEvaluation: Bool {
        switch self {
        case .taskToggled, .taskDetailOpened, .personalTaskAdded, .resourceOpened, .sponsoredSlotTapped:
            return true
        case .appBecameActive, .sponsoredSlotImpression:
            return false
        }
    }

    var topics: Set<AdTopic> {
        switch self {
        case .taskToggled, .taskDetailOpened, .personalTaskAdded, .resourceOpened, .sponsoredSlotImpression, .sponsoredSlotTapped:
            return AdContentRules.defaultSafeTopics
        case .appBecameActive:
            return []
        }
    }
}

enum AdPlacement: String {
    case inlineContextual = "inline_contextual"
}

struct AdOpportunity {
    let placement: AdPlacement
    let sourceEvent: AdEvent
    let topics: Set<AdTopic>
    let issuedAt: Date
}

struct AdPolicyConfig {
    let warmupSeconds: TimeInterval = 180
    let minimumInteractionsBeforeFirstAd: Int = 4
    let minimumSecondsBetweenAds: TimeInterval = 240
    let maxAdsPerSession: Int = 8
    let maxAdsPerRollingHour: Int = 6
}

enum AdHoldReason {
    case nonTriggerEvent
    case warmupNotFinished
    case notEnoughEngagement
    case cooldownActive
    case sessionCapReached
    case hourlyCapReached
    case lowPowerMode
}

enum AdDecision {
    case allow
    case hold(AdHoldReason)
}

enum TrackingAuthorizationState: Int, Codable {
    case notDetermined = 0
    case restricted = 1
    case denied = 2
    case authorized = 3
    case unavailable = 4

    var description: String {
        switch self {
        case .notDetermined:
            return "Not determined"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        case .authorized:
            return "Authorized"
        case .unavailable:
            return "Unavailable"
        }
    }
}

@Observable
final class AdPreferencesStore {
    static let shared = AdPreferencesStore()

    private let defaults = UserDefaults.standard
    private let wantsPersonalizedAdsKey = StorageKey.adsWantsPersonalized.rawValue
    private let trackingStateKey = StorageKey.adsTrackingAuthorizationState.rawValue
    private let hasAcceptedDisclosureKey = StorageKey.adsHasAcceptedDisclosure.rawValue

    private var hasBootstrapped = false

    var wantsPersonalizedAds: Bool = false
    var trackingAuthorizationState: TrackingAuthorizationState = .notDetermined
    var hasAcceptedDisclosure: Bool = false

    var trackingStatusDescription: String {
        trackingAuthorizationState.description
    }

    var needsInitialDisclosure: Bool {
        !hasAcceptedDisclosure
    }

    var effectivePersonalizedAdsEnabled: Bool {
        wantsPersonalizedAds && trackingAuthorizationState == .authorized
    }

    private init() {
        wantsPersonalizedAds = defaults.bool(forKey: wantsPersonalizedAdsKey)
        hasAcceptedDisclosure = defaults.bool(forKey: hasAcceptedDisclosureKey)
        let rawState = defaults.integer(forKey: trackingStateKey)
        trackingAuthorizationState = TrackingAuthorizationState(rawValue: rawState) ?? .notDetermined
    }

    @MainActor
    func bootstrapIfNeeded() {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        refreshTrackingStatusFromSystem()
    }

    @MainActor
    func updateDisclosureAccepted() {
        hasAcceptedDisclosure = true
        persist()
    }

    @MainActor
    func resetPrivacyChoices() {
        wantsPersonalizedAds = false
        hasAcceptedDisclosure = false
        refreshTrackingStatusFromSystem()
        persist()
    }

    @MainActor
    func setPersonalizedAdsRequested(_ enabled: Bool) async {
        updateDisclosureAccepted()
        wantsPersonalizedAds = enabled

        if enabled {
            let newStatus = await requestTrackingAuthorizationIfPossible()
            trackingAuthorizationState = newStatus
            if newStatus != .authorized {
                wantsPersonalizedAds = false
            }
        } else {
            refreshTrackingStatusFromSystem()
        }

        persist()
    }

    @MainActor
    func refreshTrackingStatusFromSystem() {
        trackingAuthorizationState = Self.currentTrackingAuthorizationState()
        persist()
    }

    @MainActor
    private func persist() {
        defaults.set(wantsPersonalizedAds, forKey: wantsPersonalizedAdsKey)
        defaults.set(hasAcceptedDisclosure, forKey: hasAcceptedDisclosureKey)
        defaults.set(trackingAuthorizationState.rawValue, forKey: trackingStateKey)
    }

    @MainActor
    private func requestTrackingAuthorizationIfPossible() async -> TrackingAuthorizationState {
        #if canImport(AppTrackingTransparency)
        if #available(iOS 14, *) {
            guard Bundle.main.object(forInfoDictionaryKey: "NSUserTrackingUsageDescription") != nil else {
                return .denied
            }

            let result = await withCheckedContinuation { continuation in
                ATTrackingManager.requestTrackingAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
            return Self.mapTrackingStatus(result)
        }
        #endif

        return .unavailable
    }

    private static func currentTrackingAuthorizationState() -> TrackingAuthorizationState {
        #if canImport(AppTrackingTransparency)
        if #available(iOS 14, *) {
            return mapTrackingStatus(ATTrackingManager.trackingAuthorizationStatus)
        }
        #endif

        return .unavailable
    }

    #if canImport(AppTrackingTransparency)
    @available(iOS 14, *)
    private static func mapTrackingStatus(
        _ status: ATTrackingManager.AuthorizationStatus
    ) -> TrackingAuthorizationState {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        @unknown default:
            return .unavailable
        }
    }
    #endif
}

@Observable
final class AdCoordinator {
    private(set) var sessionStartedAt: Date?
    private(set) var interactionCount = 0
    private(set) var opportunitiesIssued = 0
    private(set) var lastOpportunityAt: Date?

    private var recentOpportunityDates: [Date] = []

    private let config = AdPolicyConfig()
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.arrivaluk.app",
        category: "ad-policy"
    )

    @MainActor
    func startSessionIfNeeded(now: Date = .now) {
        guard sessionStartedAt == nil else { return }
        sessionStartedAt = now
        LaunchMetrics.mark(event: "ad_session_started")
    }

    @MainActor
    func register(event: AdEvent, now: Date = .now) -> AdOpportunity? {
        startSessionIfNeeded(now: now)

        if event.countsAsInteraction {
            interactionCount += 1
        }

        switch evaluate(event: event, now: now) {
        case .allow:
            pruneHourlyWindow(reference: now)
            opportunitiesIssued += 1
            lastOpportunityAt = now
            recentOpportunityDates.append(now)

            #if DEBUG
            logger.debug(
                "ad_allowed event=\(event.rawValue, privacy: .public) issued=\(self.opportunitiesIssued)"
            )
            #endif

            return AdOpportunity(
                placement: .inlineContextual,
                sourceEvent: event,
                topics: event.topics,
                issuedAt: now
            )
        case .hold:
            return nil
        }
    }

    @MainActor
    private func evaluate(event: AdEvent, now: Date) -> AdDecision {
        guard event.canTriggerEvaluation else { return .hold(.nonTriggerEvent) }
        guard let sessionStartedAt else { return .hold(.warmupNotFinished) }

        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            return .hold(.lowPowerMode)
        }

        if now.timeIntervalSince(sessionStartedAt) < config.warmupSeconds {
            return .hold(.warmupNotFinished)
        }

        if interactionCount < config.minimumInteractionsBeforeFirstAd {
            return .hold(.notEnoughEngagement)
        }

        if opportunitiesIssued >= config.maxAdsPerSession {
            return .hold(.sessionCapReached)
        }

        if let lastOpportunityAt,
           now.timeIntervalSince(lastOpportunityAt) < config.minimumSecondsBetweenAds {
            return .hold(.cooldownActive)
        }

        pruneHourlyWindow(reference: now)
        if recentOpportunityDates.count >= config.maxAdsPerRollingHour {
            return .hold(.hourlyCapReached)
        }

        return .allow
    }

    @MainActor
    private func pruneHourlyWindow(reference: Date) {
        let cutoff = reference.addingTimeInterval(-3600)
        recentOpportunityDates.removeAll { $0 < cutoff }
    }
}

struct AdConsentSnapshot {
    let effectivePersonalizedAdsEnabled: Bool
}

struct AdRequestContext {
    let placement: AdPlacement
    let sourceEvent: AdEvent
    let topics: Set<AdTopic>
    let nonPersonalized: Bool
}

private protocol AdNetworkClient {
    func configureIfNeeded(consent: AdConsentSnapshot)
    func updateConsent(_ consent: AdConsentSnapshot)
    func requestAd(context: AdRequestContext)
}

final class NoOpAdNetworkClient: AdNetworkClient {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.arrivaluk.app",
        category: "ad-runtime-noop"
    )

    func configureIfNeeded(consent: AdConsentSnapshot) {
        #if DEBUG
        logger.debug("ad_client_noop_configured personalized=\(consent.effectivePersonalizedAdsEnabled)")
        #endif
    }

    func updateConsent(_ consent: AdConsentSnapshot) {
        #if DEBUG
        logger.debug("ad_client_noop_consent_updated personalized=\(consent.effectivePersonalizedAdsEnabled)")
        #endif
    }

    func requestAd(context: AdRequestContext) {
        #if DEBUG
        logger.debug(
            "ad_client_noop_request placement=\(context.placement.rawValue, privacy: .public) event=\(context.sourceEvent.rawValue, privacy: .public)"
        )
        #endif
    }
}

#if canImport(GoogleMobileAds)
import GoogleMobileAds

final class GoogleMobileAdsClient: NSObject, AdNetworkClient {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.arrivaluk.app",
        category: "ad-runtime-gma"
    )

    private var isConfigured = false
    private var latestConsent = AdConsentSnapshot(effectivePersonalizedAdsEnabled: false)
    private var cachedInterstitial: GADInterstitialAd?

    private var adUnitID: String {
        let configured = Bundle.main.object(forInfoDictionaryKey: "ADMOB_INTERSTITIAL_UNIT_ID") as? String
        if let configured, !configured.isEmpty {
            return configured
        }
        #if DEBUG
        return "ca-app-pub-3940256099942544/4411468910"
        #else
        return ""
        #endif
    }

    func configureIfNeeded(consent: AdConsentSnapshot) {
        latestConsent = consent
        guard !isConfigured else { return }
        isConfigured = true

        GADMobileAds.sharedInstance().start(completionHandler: nil)

        #if DEBUG
        logger.debug("gma_started")
        #endif
    }

    func updateConsent(_ consent: AdConsentSnapshot) {
        latestConsent = consent
    }

    func requestAd(context: AdRequestContext) {
        guard isConfigured else {
            configureIfNeeded(consent: latestConsent)
            return
        }

        guard !adUnitID.isEmpty else {
            #if DEBUG
            logger.debug("gma_request_skipped_missing_release_ad_unit_id")
            #endif
            return
        }

        let request = GADRequest()
        request.keywords = context.topics.map(\.rawValue)

        if context.nonPersonalized {
            let extras = GADExtras()
            extras.additionalParameters = ["npa": "1"]
            request.register(extras)
        }

        GADInterstitialAd.load(withAdUnitID: adUnitID, request: request) { [weak self] ad, error in
            guard let self else { return }
            if let error {
                #if DEBUG
                self.logger.debug("gma_load_failed \(error.localizedDescription, privacy: .public)")
                #endif
                return
            }

            self.cachedInterstitial = ad
            #if DEBUG
            self.logger.debug("gma_interstitial_loaded")
            #endif
        }
    }
}
#endif

enum AdLegal {
    static let privacyPolicyURL = AppConfig.legal.privacyPolicyURL.absoluteString
    static let termsOfServiceURL = AppConfig.legal.termsOfServiceURL.absoluteString
    static let supportURL = AppConfig.legal.supportWebsiteURL.absoluteString
    static let dataDeletionURL = AppConfig.legal.dataDeletionRequestURL.absoluteString
}

enum AdRuntime {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.arrivaluk.app",
        category: "ad-runtime"
    )

    private static let preferences = AdPreferencesStore.shared
    private static var bootstrapped = false

    private static let adClient: any AdNetworkClient = {
        #if canImport(GoogleMobileAds)
        return GoogleMobileAdsClient()
        #else
        return NoOpAdNetworkClient()
        #endif
    }()

    /// True only when an actual ad SDK is linked into this build.
    static var isAdSDKLinked: Bool {
        #if canImport(GoogleMobileAds)
        return true
        #else
        return false
        #endif
    }

    /// Single switch for whether the app should behave as "ads enabled" in this build.
    /// If the SDK isn't linked, we avoid showing disclosure UI and avoid prompting ATT.
    static var isAdsEnabledForCurrentBuild: Bool {
        AppConfig.features.enableAds && isAdSDKLinked
    }

    @MainActor
    static func bootstrapIfNeeded() {
        guard isAdsEnabledForCurrentBuild else { return }
        guard !bootstrapped else { return }
        bootstrapped = true

        preferences.bootstrapIfNeeded()
        adClient.configureIfNeeded(consent: consentSnapshot())
    }

    @MainActor
    static func updateConsentConfiguration() {
        guard isAdsEnabledForCurrentBuild else { return }
        preferences.refreshTrackingStatusFromSystem()
        adClient.updateConsent(consentSnapshot())
    }

    @MainActor
    static func requestAd(for opportunity: AdOpportunity) {
        guard isAdsEnabledForCurrentBuild else { return }
        bootstrapIfNeeded()

        guard AdContentRules.allows(topics: opportunity.topics) else {
            #if DEBUG
            logger.debug("ad_request_blocked_by_category_filter")
            #endif
            return
        }

        let context = AdRequestContext(
            placement: opportunity.placement,
            sourceEvent: opportunity.sourceEvent,
            topics: opportunity.topics,
            nonPersonalized: !preferences.effectivePersonalizedAdsEnabled
        )

        adClient.requestAd(context: context)

        #if DEBUG
        logger.debug(
            "ad_request placement=\(opportunity.placement.rawValue, privacy: .public) source=\(opportunity.sourceEvent.rawValue, privacy: .public)"
        )
        #endif
    }

    @MainActor
    private static func consentSnapshot() -> AdConsentSnapshot {
        AdConsentSnapshot(
            effectivePersonalizedAdsEnabled: preferences.effectivePersonalizedAdsEnabled
        )
    }
}
