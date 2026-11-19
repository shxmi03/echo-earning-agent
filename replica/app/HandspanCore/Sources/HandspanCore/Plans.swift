import Foundation

// S05: the plans on sale (launch/pricing.md). Product ids match App Store Connect and the
// `appstore` edge function (supabase/functions/appstore), which maps them to `subscriptions.plan`.

public enum PlanSize: String, Sendable, CaseIterable, Identifiable {
    case solo, household
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .solo: "Solo"
        case .household: "Household"
        }
    }

    public var learners: Int { self == .solo ? 1 : 5 }
    /// `subscriptions.plan` in the database.
    public var databasePlan: String { self == .solo ? "individual" : "family" }

    public var detail: String {
        switch self {
        case .solo: "One learner."
        case .household: "Up to 5 learners on one account, each with their own progress."
        }
    }
}

public enum PlanPeriod: String, Sendable, CaseIterable, Identifiable {
    case monthly, yearly
    public var id: String { rawValue }
    public var title: String { self == .monthly ? "Monthly" : "Yearly" }
    public var unit: String { self == .monthly ? "month" : "year" }
}

public struct Plan: Sendable, Hashable, Identifiable {
    public let size: PlanSize
    public let period: PlanPeriod
    /// Shown until StoreKit returns the real, local price. Same numbers as pricing.md.
    public let fallbackPrice: Decimal

    public var id: String { productId }
    public var productId: String { "app.handspan.\(size.rawValue).\(period.rawValue)" }

    public static let all: [Plan] = [
        Plan(size: .solo, period: .monthly, fallbackPrice: 9.99),
        Plan(size: .solo, period: .yearly, fallbackPrice: 99.99),
        Plan(size: .household, period: .monthly, fallbackPrice: 14.99),
        Plan(size: .household, period: .yearly, fallbackPrice: 149.99),
    ]

    public static var productIds: [String] { all.map(\.productId) }

    public static func find(_ size: PlanSize, _ period: PlanPeriod) -> Plan {
        all.first { $0.size == size && $0.period == period }!
    }

    public static func from(productId: String) -> Plan? { all.first { $0.productId == productId } }

    public static let trialDays = 7
}

public enum PaywallCopy {
    /// The line under the button: what happens, when, for how much (pricing.md: "Then
    /// $9.99 on Nov 26"). Written out so nobody is surprised by the first charge.
    public static func chargeLine(price: String, period: PlanPeriod, trial: Bool, from now: Date,
                                  calendar: Calendar = .current, locale: Locale = .current) -> String {
        guard trial else {
            return "\(price) a \(period.unit) from today. Cancel any time in Settings."
        }
        let date = calendar.date(byAdding: .day, value: Plan.trialDays, to: now) ?? now
        let style = Date.FormatStyle(date: .abbreviated, time: .omitted, locale: locale,
                                     calendar: calendar, timeZone: calendar.timeZone)
        let day = date.formatted(style)
        return "Free for \(Plan.trialDays) days, then \(price) a \(period.unit) from \(day). We'll remind you 2 days before. Cancel any time in Settings."
    }

    /// "Saves 2 months" for yearly: twelve monthly payments against one yearly one.
    public static func yearlySaving(monthly: Decimal, yearly: Decimal) -> String? {
        guard monthly > 0 else { return nil }
        let months = NSDecimalNumber(decimal: (monthly * 12 - yearly) / monthly).doubleValue.rounded()
        guard months >= 1 else { return nil }
        return months == 1 ? "Saves 1 month" : "Saves \(Int(months)) months"
    }
}
