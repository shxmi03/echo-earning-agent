import Foundation
import HandspanCore
import Observation
import StoreKit

/// StoreKit 2: loads the four plans, buys, restores, and keeps the entitlement current.
/// Every verified transaction is also sent to the backend (`appstore/sync`), which
/// checks Apple's signature again on the server before it writes `subscriptions`.
@MainActor @Observable
final class StoreModel {
    enum LoadState: Equatable { case idle, loading, loaded, failed }
    enum PurchaseOutcome: Equatable { case purchased, pending, cancelled, failed(String) }

    private(set) var products: [String: Product] = [:]
    private(set) var loadState: LoadState = .idle
    /// The plan this Apple ID is subscribed to right now, if any.
    private(set) var activePlan: Plan?
    /// Whether this Apple ID can still get the free week (one per subscription group).
    private(set) var trialAvailable = true
    /// The latest transaction, for "Request a refund".
    private(set) var latestTransactionId: UInt64?

    @ObservationIgnored private var updates: Task<Void, Never>?
    /// Set by the app: sends a verified transaction to the backend.
    @ObservationIgnored var syncToServer: @MainActor (String) async -> Void = { _ in }

    init() {
        updates = Task { [weak self] in
            // Renewals, refunds, Ask to Buy approvals and purchases on other devices.
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
    }

    var hasPremium: Bool { activePlan != nil }

    func load() async {
        guard loadState != .loading else { return }
        loadState = .loading
        do {
            let list = try await Product.products(for: Plan.productIds)
            products = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
            if let any = list.first, let group = any.subscription?.subscriptionGroupID {
                trialAvailable = await Product.SubscriptionInfo.isEligibleForIntroOffer(for: group)
            }
            loadState = .loaded
        } catch {
            loadState = .failed
        }
        await refreshEntitlement()
    }

    /// The App Store's price in the user's currency, or the planned US price until it loads.
    func price(of plan: Plan) -> String {
        if let product = products[plan.productId] { return product.displayPrice }
        return plan.fallbackPrice.formatted(.currency(code: "USD"))
    }

    func hasTrial(_ plan: Plan) -> Bool {
        guard trialAvailable else { return false }
        guard let product = products[plan.productId] else { return true }   // planned: every plan has one
        return product.subscription?.introductoryOffer?.paymentMode == .freeTrial
    }

    func purchase(_ plan: Plan, accountId: UUID?) async -> PurchaseOutcome {
        guard let product = products[plan.productId] else {
            return .failed("The plans aren't available right now. Check your connection and try again.")
        }
        var options: Set<Product.PurchaseOption> = []
        // Ties the purchase to this Handspan account, so the server can refuse a receipt
        // that someone else's account tries to claim.
        if let accountId { options.insert(.appAccountToken(accountId)) }
        do {
            switch try await product.purchase(options: options) {
            case .success(let result):
                await handle(result)
                return .purchased
            case .pending:
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .cancelled
            }
        } catch {
            return .failed("The purchase didn't go through. You haven't been charged.")
        }
    }

    /// "Restore purchases": asks the App Store for this Apple ID's transactions.
    func restore() async -> Bool {
        do { try await AppStore.sync() } catch { return false }
        await refreshEntitlement()
        return hasPremium
    }

    func refreshEntitlement() async {
        var best: (Plan, Date)?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result, t.revocationDate == nil,
                  let plan = Plan.from(productId: t.productID) else { continue }
            latestTransactionId = t.id
            let expires = t.expirationDate ?? .distantFuture
            if expires > .now, best == nil || plan.size == .household {
                best = (plan, expires)
            }
        }
        activePlan = best?.0
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }   // never unlock on a bad signature
        latestTransactionId = transaction.id
        await syncToServer(result.jwsRepresentation)
        await transaction.finish()
        await refreshEntitlement()
    }
}
