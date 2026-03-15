import AppIntents
import SwiftUI
import WidgetKit

@available(iOS 18.0, *)
struct ArrivalWalletControlWidget: ControlWidget {
    static let kind = "ArrivalWalletControlWidget"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(
                action: OpenURLIntent(
                    ArrivalWidgetShared.walletDeepLinkURL(
                        shouldUnlock: true,
                        documentRawValue: "studentVisa"
                    ) ?? URL(string: "arrivaluk://wallet?unlock=1")!
                )
            ) {
                Label("Show BRP", systemImage: "person.text.rectangle")
            }
        }
        .displayName("Arrival Wallet")
        .description("Open BRP in secure wallet.")
    }
}

@available(iOS 18.0, *)
struct ArrivalQuickTaskControlWidget: ControlWidget {
    static let kind = "ArrivalQuickTaskControlWidget"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(
                action: OpenURLIntent(
                    ArrivalWidgetShared.quickTaskDeepLinkURL() ?? URL(string: "arrivaluk://quicktask")!
                )
            ) {
                Label("Quick Task", systemImage: "checklist.checked")
            }
        }
        .displayName("Arrival Quick Task")
        .description("Jump to your next priority.")
    }
}

@available(iOS 18.0, *)
struct ArrivalDiscountQRControlWidget: ControlWidget {
    static let kind = "ArrivalDiscountQRControlWidget"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(
                action: OpenURLIntent(
                    ArrivalWidgetShared.discountQRDeepLinkURL() ?? URL(string: "arrivaluk://discountqr")!
                )
            ) {
                Label("Discount QR", systemImage: "qrcode")
            }
        }
        .displayName("Arrival Discount QR")
        .description("Open student discount scanner.")
    }
}
