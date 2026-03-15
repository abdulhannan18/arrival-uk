import Foundation

enum UKLocaleFormat {
    static func mediumDateString(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    static func currencyString(_ amount: Decimal) -> String {
        let value = NSDecimalNumber(decimal: amount)
        return currencyFormatter.string(from: value) ?? "0.00"
    }

    static func currencyString(_ amount: Double) -> String {
        currencyString(Decimal(amount))
    }

    private static var dateFormatter: DateFormatter {
        let configuration = RegionRuntime.activeConfiguration
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: configuration.localeIdentifier)
        formatter.dateFormat = configuration.dateFormat
        return formatter
    }

    private static var currencyFormatter: NumberFormatter {
        let configuration = RegionRuntime.activeConfiguration
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: configuration.localeIdentifier)
        formatter.numberStyle = .currency
        formatter.currencyCode = configuration.currencyCode
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter
    }
}
