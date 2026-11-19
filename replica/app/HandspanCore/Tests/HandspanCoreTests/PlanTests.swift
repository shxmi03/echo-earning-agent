import Foundation
import Testing
@testable import HandspanCore

@Suite struct PlanTests {
    @Test func productIdsMatchAppStoreConnect() {
        #expect(Plan.productIds == ["app.handspan.solo.monthly", "app.handspan.solo.yearly",
                                    "app.handspan.household.monthly", "app.handspan.household.yearly"])
        #expect(Plan.from(productId: "app.handspan.household.yearly")?.size == .household)
        #expect(Plan.from(productId: "something.else") == nil)
        #expect(PlanSize.household.learners == 5)
        #expect(PlanSize.solo.databasePlan == "individual")
        #expect(PlanSize.household.databasePlan == "family")
    }

    @Test func yearlySavesTwoMonths() {
        #expect(PaywallCopy.yearlySaving(monthly: 9.99, yearly: 99.99) == "Saves 2 months")
        #expect(PaywallCopy.yearlySaving(monthly: 14.99, yearly: 149.99) == "Saves 2 months")
        #expect(PaywallCopy.yearlySaving(monthly: 10, yearly: 120) == nil)
    }

    @Test func chargeLineSaysWhenAndHowMuch() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = try #require(TimeZone(identifier: "UTC"))
        let now = Date(timeIntervalSince1970: 1_795_132_800)   // 2026-11-20 00:00 UTC
        let line = PaywallCopy.chargeLine(price: "$9.99", period: .monthly, trial: true, from: now,
                                          calendar: cal, locale: Locale(identifier: "en_US"))
        #expect(line.hasPrefix("Free for 7 days, then $9.99 a month from Nov 27, 2026."))
        #expect(line.contains("remind you 2 days before"))
        let noTrial = PaywallCopy.chargeLine(price: "$99.99", period: .yearly, trial: false, from: now,
                                             calendar: cal, locale: Locale(identifier: "en_US"))
        #expect(noTrial == "$99.99 a year from today. Cancel any time in Settings.")
    }
}
