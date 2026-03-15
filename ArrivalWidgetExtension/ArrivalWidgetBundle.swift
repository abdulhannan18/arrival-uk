import WidgetKit
import SwiftUI

@main
struct ArrivalWidgetBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        ArrivalTodayWidget()
        if #available(iOS 16.1, *) {
            ArrivalLiveActivityWidget()
        }
        if #available(iOS 18.0, *) {
            ArrivalWalletControlWidget()
            ArrivalQuickTaskControlWidget()
            ArrivalDiscountQRControlWidget()
        }
    }
}
