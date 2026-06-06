import StoreKit
import os

/// Owns the app's single non-consumable "Pro unlock" purchase via StoreKit 2.
///
/// The app is free to build and run any workout; saving/reusing named
/// favorites is the premium feature gated behind `isUnlocked`. This mirrors
/// the proven Seconds model: the user experiences the full app, and the
/// paywall only appears at the high-intent moment of saving.
///
/// StoreKit 2 gives us transaction verification for free (`VerificationResult`),
/// a live `Transaction.updates` stream for purchases made elsewhere (e.g.
/// Ask-to-Buy approvals, another device), and `Transaction.currentEntitlements`
/// as the authoritative source of truth at launch.
/// Outcome of a purchase attempt, so the paywall can react precisely —
/// a user cancel must not look like a failure.
enum PurchaseOutcome {
    case success
    case cancelled
    case pending
    case failed
}

@MainActor
@Observable
final class StoreManager {
    /// Must match the product ID in App Store Connect and `ProUnlock.storekit`.
    static let unlockProductID = "com.superapp.intervalv1.pro_unlock"

    /// True when the user owns the Pro unlock. Drives every paywall gate.
    private(set) var isUnlocked = false

    /// The loaded product (nil until `Product.products(for:)` resolves, or if
    /// the store is unreachable). Used for the localized price in the paywall.
    private(set) var product: Product?

    /// True while a purchase round-trip is in flight, so the paywall can show
    /// a spinner and disable the buy button.
    private(set) var purchaseInFlight = false

    /// Localized price string (e.g. "€ 4,99"), or nil if the product hasn't
    /// loaded yet — the paywall falls back to a neutral label in that case.
    var displayPrice: String? { product?.displayPrice }

    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    private let log = Logger(subsystem: "com.superapp.intervalv1", category: "Store")

    init() {
        // Listen for transactions that arrive outside an explicit purchase()
        // call — Ask-to-Buy approvals, purchases on another device, refunds.
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    /// Load the product and reconcile entitlements. Call once at launch.
    func start() async {
        await loadProduct()
        await refreshEntitlements()
    }

    func loadProduct() async {
        do {
            let products = try await Product.products(for: [Self.unlockProductID])
            product = products.first
            if product == nil {
                log.warning("Pro unlock product not found for id \(Self.unlockProductID, privacy: .public)")
            }
        } catch {
            log.error("Loading product failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Authoritative ownership check: scan current entitlements for a
    /// non-revoked unlock transaction.
    func refreshEntitlements() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.unlockProductID,
               transaction.revocationDate == nil {
                unlocked = true
            }
        }
        isUnlocked = unlocked
    }

    /// Start the purchase flow. The returned `PurchaseOutcome` lets the paywall
    /// continue on success, stay quiet on cancel, and only alert on failure.
    func purchase() async -> PurchaseOutcome {
        guard let product else {
            log.error("Purchase attempted with no loaded product")
            return .failed
        }
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    log.error("Purchase succeeded but failed verification")
                    return .failed
                }
                await transaction.finish()
                isUnlocked = true
                return .success
            case .userCancelled:
                return .cancelled
            case .pending:
                // Ask-to-Buy / SCA — the result will arrive via Transaction.updates.
                return .pending
            @unknown default:
                return .failed
            }
        } catch {
            log.error("Purchase failed: \(error.localizedDescription, privacy: .public)")
            return .failed
        }
    }

    /// Apple-required restore path. `AppStore.sync()` forces a refresh against
    /// the App Store, after which we re-read entitlements.
    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            log.error("Restore (AppStore.sync) failed: \(error.localizedDescription, privacy: .public)")
        }
        await refreshEntitlements()
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        if transaction.productID == Self.unlockProductID,
           transaction.revocationDate == nil {
            isUnlocked = true
        } else if transaction.productID == Self.unlockProductID {
            // Revoked (refund / family-sharing removal) — re-lock.
            isUnlocked = false
        }
        await transaction.finish()
    }
}
