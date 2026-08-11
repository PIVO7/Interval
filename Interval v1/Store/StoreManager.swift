import StoreKit
import os

/// Outcome of a purchase attempt, so the paywall can react precisely —
/// a user cancel must not look like a failure.
enum PurchaseOutcome {
    case success
    case cancelled
    case pending
    case failed
}

/// Owns the app's single non-consumable "Pro unlock" purchase via StoreKit 2.
///
/// **The app charges for Pro:** `freeForEveryone` is `false`, so favorites
/// and colour themes are gated behind the one-time unlock and the paywall
/// shows for non-buyers. Flip `freeForEveryone` back to `true` to ship
/// everything free again — all gates and the Account Pro card key off it.
///
/// StoreKit 2 gives us transaction verification for free (`VerificationResult`),
/// a live `Transaction.updates` stream for purchases made elsewhere (e.g.
/// Ask-to-Buy approvals, another device), and `Transaction.currentEntitlements`
/// as the authoritative source of truth at launch.
@MainActor
@Observable
final class StoreManager {
    /// Master switch. While `true` the whole app is free and the paywall is
    /// suppressed — the single place to flip to monetize again.
    static let freeForEveryone = false

    /// Must match the product ID in App Store Connect and `ProUnlock.storekit`.
    static let unlockProductID = "com.superapp.intervalv1.pro_unlock"

    /// Real StoreKit entitlement state. Read ownership through `isUnlocked`,
    /// which also honours `freeForEveryone`.
    private(set) var entitlementUnlocked = false

    /// Whether Pro features are unlocked. Always `true` while the app is free;
    /// otherwise reflects the actual purchase. Drives every gate.
    var isUnlocked: Bool { Self.freeForEveryone || entitlementUnlocked }

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
        entitlementUnlocked = unlocked
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
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    entitlementUnlocked = true
                    return .success
                case .unverified(let transaction, let error):
                    // Don't unlock on an unverified result, but DO finish it so
                    // StoreKit stops redelivering it on the updates stream.
                    log.error("Purchase failed verification: \(error.localizedDescription, privacy: .public)")
                    await transaction.finish()
                    return .failed
                }
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
    /// the App Store, after which we re-read entitlements. Throws on a sync
    /// failure (e.g. no network) so callers can surface feedback.
    func restore() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        switch result {
        case .verified(let transaction):
            if transaction.productID == Self.unlockProductID {
                // nil revocationDate = active; non-nil = refunded / removed.
                entitlementUnlocked = transaction.revocationDate == nil
            }
            await transaction.finish()
        case .unverified(let transaction, _):
            // Finish so it doesn't redeliver indefinitely; never unlock on it.
            await transaction.finish()
        }
    }
}
