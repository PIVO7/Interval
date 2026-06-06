import SwiftUI
import StoreKit

/// One-time "Interval Pro" unlock paywall, shown the moment a free user tries
/// to save a favorite. Deliberately framed around the value the user just
/// reached for (saving + reusing named workouts) rather than a generic
/// feature wall.
///
/// `onUnlocked` fires after a successful purchase or restore so the caller can
/// immediately continue the action the user intended (open the save sheet).
struct PaywallView: View {
    var onUnlocked: () -> Void = {}

    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var showError = false
    @State private var showPending = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 28) {
                        hero
                        benefits
                        Spacer(minLength: 8)
                        purchaseSection
                    }
                    .padding(24)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Interval Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Sluit") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Herstel") {
                        Task { await restore() }
                    }
                    .disabled(store.purchaseInFlight)
                }
            }
            .alert("Aankoop niet gelukt", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Er is niets in rekening gebracht. Probeer het later opnieuw.")
            }
            .alert("Aankoop in behandeling", isPresented: $showPending) {
                Button("OK", role: .cancel) { dismiss() }
            } message: {
                Text("Je aankoop wacht op goedkeuring. Zodra die rond is, wordt Interval Pro automatisch ontgrendeld.")
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Hero
    private var hero: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.workGradient)
                    .frame(width: 96, height: 96)
                Image(systemName: "heart.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white)
            }
            .padding(.top, 12)
            VStack(spacing: 8) {
                Text("Bewaar je favorieten")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
                    .multilineTextAlignment(.center)
                Text("Eenmalig kopen. Geen abonnement. Voor altijd van jou.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Benefits
    private var benefits: some View {
        VStack(spacing: 0) {
            benefitRow(
                icon: "square.and.arrow.down.fill",
                title: "Onbeperkt opslaan",
                subtitle: "Bewaar al je workouts met een eigen naam."
            )
            Divider().padding(.leading, 60)
            benefitRow(
                icon: "arrow.clockwise",
                title: "Altijd herbruikbaar",
                subtitle: "Start je opgeslagen favorieten zo vaak je wilt."
            )
            Divider().padding(.leading, 60)
            benefitRow(
                icon: "icloud.fill",
                title: "Synct overal",
                subtitle: "Je favorieten staan op al je apparaten."
            )
        }
        .softCard()
    }

    private func benefitRow(icon: String, title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(AppTheme.coral.opacity(0.18)).frame(width: 36, height: 36)
                Image(systemName: icon).foregroundStyle(AppTheme.coral).font(.callout)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Text(subtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Purchase
    private var purchaseSection: some View {
        VStack(spacing: 12) {
            Button {
                Task { await buy() }
            } label: {
                ZStack {
                    if store.purchaseInFlight {
                        ProgressView().tint(.white)
                    } else {
                        Text(buyButtonTitle)
                            .font(.system(.headline, design: .rounded, weight: .bold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppTheme.workGradient)
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
            .disabled(store.purchaseInFlight || store.product == nil)

            Text("Eenmalige aankoop · geen abonnement")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(.bottom, 12)
    }

    private var buyButtonTitle: LocalizedStringKey {
        if let price = store.displayPrice {
            return "Ontgrendel voor \(price)"
        }
        return "Ontgrendel Interval Pro"
    }

    // MARK: - Actions
    private func buy() async {
        switch await store.purchase() {
        case .success:
            onUnlocked()
            dismiss()
        case .pending:
            showPending = true
        case .failed:
            showError = true
        case .cancelled:
            break // user backed out — stay on the paywall, say nothing
        }
    }

    private func restore() async {
        do {
            try await store.restore()
        } catch {
            showError = true
            return
        }
        if store.isUnlocked {
            onUnlocked()
            dismiss()
        }
    }
}
