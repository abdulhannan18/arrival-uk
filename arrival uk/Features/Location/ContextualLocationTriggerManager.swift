import CoreLocation
import Foundation
import UserNotifications

@available(iOS 17.0, *)
@MainActor
final class ContextualLocationTriggerManager: NSObject, CLLocationManagerDelegate {
    static let shared = ContextualLocationTriggerManager()

    private let locationManager = CLLocationManager()
    private let notificationCenter = UNUserNotificationCenter.current()
    private var isConfigured = false

    private let triggerCooldown: TimeInterval = 60 * 60
    private let lastTriggerPrefix = "location.region.lastTrigger."

    private override init() {
        super.init()
    }

    func configureIfNeeded() {
        guard !isConfigured else { return }
        isConfigured = true
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.pausesLocationUpdatesAutomatically = true
        syncAuthorizationFlow()
    }

    private func syncAuthorizationFlow() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestAlwaysAuthorization()
        case .authorizedAlways:
            startMonitoringRegionsIfNeeded()
        case .authorizedWhenInUse:
            // Request upgrade so region callbacks can wake in background.
            locationManager.requestAlwaysAuthorization()
            startMonitoringRegionsIfNeeded()
        case .restricted, .denied:
            break
        @unknown default:
            break
        }
    }

    private func startMonitoringRegionsIfNeeded() {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            CrashReporter.log("Region monitoring unavailable on this device", level: .warning)
            return
        }

        // Keep only this manager's regions registered.
        for region in locationManager.monitoredRegions where region.identifier.hasPrefix("arrival.context.") {
            locationManager.stopMonitoring(for: region)
        }

        for region in monitoredRegions {
            locationManager.startMonitoring(for: region)
        }

        // Battery-efficient fallback that avoids continuous GPS.
        locationManager.startMonitoringSignificantLocationChanges()
    }

    private var monitoredRegions: [CLCircularRegion] {
        [
            makeRegion(
                identifier: "arrival.context.postOffice.central",
                latitude: 51.5155,
                longitude: -0.0998,
                radius: 220
            ),
            makeRegion(
                identifier: "arrival.context.highStreet.oxford",
                latitude: 51.5154,
                longitude: -0.1410,
                radius: 250
            ),
            makeRegion(
                identifier: "arrival.context.campus.ucl",
                latitude: 51.5246,
                longitude: -0.1340,
                radius: 260
            )
        ]
    }

    private func makeRegion(
        identifier: String,
        latitude: CLLocationDegrees,
        longitude: CLLocationDegrees,
        radius: CLLocationDistance
    ) -> CLCircularRegion {
        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            radius: radius,
            identifier: identifier
        )
        region.notifyOnEntry = true
        region.notifyOnExit = false
        return region
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.syncAuthorizationFlow()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        Task { @MainActor in
            guard let context = self.contextForRegionIdentifier(region.identifier) else { return }

            ArrivalWidgetSupport.syncLocationContext(context)

            let shouldTrigger = self.shouldTriggerNotification(for: context)
            guard shouldTrigger else { return }

            await self.scheduleContextNotification(for: context)
            self.recordRegionTrigger(for: context)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            CrashReporter.record(error: error, context: "location_region_monitoring")
        }
    }

    private func contextForRegionIdentifier(_ identifier: String) -> ArrivalWidgetSupport.LocationContext? {
        if identifier.contains("postOffice") {
            return .postOffice
        }
        if identifier.contains("highStreet") {
            return .highStreet
        }
        if identifier.contains("campus") {
            return .campus
        }
        return nil
    }

    private func shouldTriggerNotification(for context: ArrivalWidgetSupport.LocationContext) -> Bool {
        let key = lastTriggerPrefix + context.rawValue
        let lastTimestamp = UserDefaults.standard.double(forKey: key)
        guard lastTimestamp > 0 else { return true }
        let lastDate = Date(timeIntervalSince1970: lastTimestamp)
        return Date().timeIntervalSince(lastDate) >= triggerCooldown
    }

    private func recordRegionTrigger(for context: ArrivalWidgetSupport.LocationContext) {
        let key = lastTriggerPrefix + context.rawValue
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: key)
    }

    private func scheduleContextNotification(for context: ArrivalWidgetSupport.LocationContext) async {
        let settings = await notificationCenter.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }

        let content = UNMutableNotificationContent()
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        switch context {
        case .postOffice:
            content.title = "You're at the Post Office"
            content.body = "Tap to open your Passport and CAS letter instantly."
        case .highStreet:
            content.title = "Nearby student discount"
            content.body = "You're near high-street offers. Scan your student QR and save now."
        case .campus:
            content.title = "On campus now"
            content.body = "Open your Student ID and key setup docs before class."
        case .unknown:
            content.title = "Arrival UK"
            content.body = "Open your secure wallet and checklist."
        }

        content.userInfo = [
            "type": "contextual_region",
            "context": context.rawValue,
            "deepLink": ArrivalWidgetSupport.walletDeepLinkURL(shouldUnlock: true)?.absoluteString ?? "arrivaluk://wallet?unlock=1"
        ]

        switch context {
        case .postOffice:
            await ArrivalLiveActivityManager.shared.startOrUpdate(
                taskTitle: "Post Office Visit",
                currentStep: "BRP Ready to Collect",
                progress: 0.8,
                documentSymbol: "person.text.rectangle.fill"
            )
        case .highStreet:
            await ArrivalLiveActivityManager.shared.startOrUpdate(
                taskTitle: "Student Discounts",
                currentStep: "QR Discount Nearby",
                progress: 0.45,
                documentSymbol: "qrcode"
            )
        case .campus:
            await ArrivalLiveActivityManager.shared.startOrUpdate(
                taskTitle: "Campus Essentials",
                currentStep: "ID & Timetable Ready",
                progress: 0.6,
                documentSymbol: "studentdesk"
            )
        case .unknown:
            await ArrivalLiveActivityManager.shared.endCurrentIfNeeded()
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let identifier = "arrival.contextual.\(context.rawValue).\(Int(Date().timeIntervalSince1970))"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await notificationCenter.add(request)
        } catch {
            CrashReporter.record(error: error, context: "contextual_location_notification")
        }
    }
}
