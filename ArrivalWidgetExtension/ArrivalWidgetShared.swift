import Foundation
import SwiftUI

enum ArrivalWidgetShared {
    static let kind = "ArrivalTodayWidget"
    static let appGroupID = "group.com.arrivaluk.shared"
    static let snapshotKey = "arrival.widget.snapshot.v1"
    static let locationContextKey = "arrival.widget.locationContext.v1"
    static let deepLinkScheme = "arrivaluk"
    static let quickTaskHost = "quicktask"
    static let discountQRHost = "discountqr"

    struct Snapshot: Codable {
        let taskTitle: String
        let minutes: Int
        let categoryHex: String
        let categoryID: String
        let taskID: String
        let updatedAt: Date
    }

    enum LocationContext: String, Codable {
        case campus
        case highStreet
        case postOffice
        case unknown
    }

    struct LocationSnapshot: Codable {
        let context: LocationContext
        let updatedAt: Date
    }

    static let fallbackSnapshot = Snapshot(
        taskTitle: "Open Arrival UK",
        minutes: 5,
        categoryHex: "1A3A8B",
        categoryID: "",
        taskID: "",
        updatedAt: .now
    )

    static func deepLinkURL(for snapshot: Snapshot) -> URL? {
        guard !snapshot.categoryID.isEmpty, !snapshot.taskID.isEmpty else {
            return nil
        }

        var components = URLComponents()
        components.scheme = deepLinkScheme
        components.host = "task"
        components.queryItems = [
            URLQueryItem(name: "categoryID", value: snapshot.categoryID),
            URLQueryItem(name: "taskID", value: snapshot.taskID)
        ]
        return components.url
    }

    static func walletDeepLinkURL(shouldUnlock: Bool = true, documentRawValue: String? = nil) -> URL {
        var queryItems = [
            URLQueryItem(name: "unlock", value: shouldUnlock ? "1" : "0")
        ]
        if let documentRawValue {
            queryItems.append(URLQueryItem(name: "document", value: documentRawValue))
        }
        return requiredDeepLinkURL(host: "wallet", queryItems: queryItems)
    }

    static func quickTaskDeepLinkURL() -> URL {
        requiredDeepLinkURL(host: quickTaskHost)
    }

    static func discountQRDeepLinkURL() -> URL {
        requiredDeepLinkURL(host: discountQRHost)
    }

    private static func requiredDeepLinkURL(
        host: String,
        queryItems: [URLQueryItem] = []
    ) -> URL {
        var components = URLComponents()
        components.scheme = deepLinkScheme
        components.host = host
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else {
            assertionFailure("Internal widget deep link components are invalid.")
            return URL(fileURLWithPath: "/")
        }
        return url
    }
}

extension Color {
    init(widgetHex: String) {
        let sanitized = widgetHex
            .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            .uppercased()

        guard sanitized.count == 6, let value = UInt32(sanitized, radix: 16) else {
            self = Color(red: 0.10, green: 0.23, blue: 0.54)
            return
        }

        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0

        self = Color(red: red, green: green, blue: blue)
    }
}
