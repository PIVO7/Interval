import SwiftUI
import SwiftData
import CloudKit

struct AccountView: View {
    @Environment(AudioSettings.self) private var audioSettings
    @Environment(AppearanceSettings.self) private var appearance
    @Environment(StoreManager.self) private var pro
    @Environment(\.scenePhase) private var scenePhase

    @State private var showPaywall = false
    @State private var restoreInFlight = false
    /// Signed in to iCloud on this device. Starts optimistic so the card
    /// doesn't flash a warning; re-checked on appear and on return to the
    /// foreground, since the user can sign in from Settings meanwhile.
    @State private var iCloudAvailable = true

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        syncCard
                        // Pro upgrade/restore card; hidden only when the app
                        // ships free (StoreManager.freeForEveryone).
                        if !StoreManager.freeForEveryone { proSection }
                        signalSection
                        appearanceSection
                        themeSection
                    }
                    .padding(20)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Account")
            .task { await refreshICloudStatus() }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task { await refreshICloudStatus() }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    // MARK: - Pro
    private var proSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Roundly Pro")
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(AppTheme.coral.opacity(0.18)).frame(width: 36, height: 36)
                        Image(systemName: pro.isUnlocked ? "checkmark.seal.fill" : "heart.fill")
                            .foregroundStyle(AppTheme.coral)
                            .font(.callout)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pro.isUnlocked ? "Roundly Pro actief" : "Bewaar je favorieten")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)
                        Text(pro.isUnlocked
                             ? "Bedankt! Je kunt onbeperkt favorieten opslaan."
                             : "Eenmalig ontgrendelen om workouts te bewaren.")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(AppTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    if !pro.isUnlocked {
                        Button("Ontgrendel") { showPaywall = true }
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(AppTheme.coral)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if !pro.isUnlocked {
                    Divider().padding(.leading, 60)
                    Button {
                        Task { await restorePurchases() }
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle().fill(AppTheme.sage.opacity(0.18)).frame(width: 30, height: 30)
                                Image(systemName: "arrow.clockwise").foregroundStyle(AppTheme.sage).font(.caption)
                            }
                            Text("Herstel aankopen")
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(AppTheme.primaryText)
                            Spacer()
                            if restoreInFlight {
                                ProgressView()
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(restoreInFlight)
                }
            }
            .softCard()
        }
        .animation(.appSmooth, value: pro.isUnlocked)
    }

    private func restorePurchases() async {
        restoreInFlight = true
        defer { restoreInFlight = false }
        try? await pro.restore()
    }

    // MARK: - iCloud sync
    /// No account of our own: favorites sync through the user's private
    /// iCloud database. This card only says whether that's active here.
    private var syncCard: some View {
        HStack(spacing: 16) {
            BrandIconCircle {
                Image(systemName: iCloudAvailable ? "checkmark.icloud.fill" : "icloud.slash.fill")
                    .font(.title)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(iCloudAvailable ? "Gesynchroniseerd via iCloud" : "iCloud staat uit")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
                Text(iCloudAvailable
                     ? "Je favorieten staan automatisch op al je toestellen met hetzelfde Apple-account."
                     : "Je favorieten worden alleen op dit toestel bewaard. Log in bij iCloud in Instellingen om ze op al je toestellen te hebben.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(20)
        .softCard()
        .accessibilityElement(children: .combine)
        .animation(.appSmooth, value: iCloudAvailable)
    }

    /// `CKContainer.default()` is the container from the entitlements —
    /// the same one SwiftData syncs through.
    private func refreshICloudStatus() async {
        // A failed check (e.g. offline) keeps the last known state.
        guard let status = try? await CKContainer.default().accountStatus() else { return }
        iCloudAvailable = status == .available
    }

    // MARK: - Signal tones & haptics
    private var signalSection: some View {
        @Bindable var audioSettings = audioSettings
        return VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Signalen")
            VStack(spacing: 0) {
                toggleRow(
                    icon: "bell.badge.fill",
                    tint: AppTheme.amber,
                    label: "Signaaltonen",
                    sub: "Toon bij start work/rest en laatste 3s",
                    isOn: $audioSettings.signalTonesEnabled
                )
                Divider().padding(.leading, 60)
                toggleRow(
                    icon: "waveform",
                    tint: AppTheme.coral,
                    label: "Haptic feedback",
                    sub: "Trillen bij elke fase-overgang",
                    isOn: $audioSettings.hapticsEnabled
                )
            }
            .softCard()
        }
    }

    // MARK: - Appearance
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Weergave")
            VStack(spacing: 0) {
                // Array(enumerated()) wrap is required for ForEach until
                // iOS 26 — EnumeratedSequence only conforms to
                // RandomAccessCollection on iOS 26+, and we deploy to 18.
                ForEach(Array(AppearanceMode.allCases.enumerated()), id: \.element.id) { idx, mode in
                    Button {
                        appearance.mode = mode
                    } label: {
                        appearanceRow(mode: mode, selected: appearance.mode == mode)
                    }
                    .buttonStyle(.plain)
                    if idx < AppearanceMode.allCases.count - 1 {
                        Divider().padding(.leading, 60)
                    }
                }
            }
            .softCard()
        }
        .animation(.appSmooth, value: appearance.mode)
    }

    // MARK: - Workout colours (Pro)
    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                sectionHeader("Trainingskleuren")
                if !pro.isUnlocked { proBadge }
                Spacer()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(PhaseTheme.all) { theme in
                        themeChip(theme)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .softCard()
        }
        .animation(.appSmooth, value: appearance.phaseThemeID)
    }

    private var proBadge: some View {
        Text("Pro")
            .font(.system(.caption2, design: .rounded, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Capsule().fill(AppTheme.coral.opacity(0.18)))
            .foregroundStyle(AppTheme.coral)
    }

    private func themeChip(_ theme: PhaseTheme) -> some View {
        let selected = appearance.phaseThemeID == theme.id
        return Button {
            selectTheme(theme)
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    // Work / rest gradients split down the middle.
                    HStack(spacing: 0) {
                        Rectangle().fill(theme.workSwatch)
                        Rectangle().fill(theme.restSwatch)
                    }
                    .frame(width: 76, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(selected ? AppTheme.primaryText : AppTheme.secondaryText.opacity(0.25),
                                lineWidth: selected ? 3 : 1)
                        .frame(width: 76, height: 76)

                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.25), radius: 2)
                    } else if !pro.isUnlocked {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(5)
                            .background(Circle().fill(.black.opacity(0.28)))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .padding(6)
                    }
                }
                Text(theme.name)
                    .font(.system(.caption, design: .rounded, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? AppTheme.primaryText : AppTheme.secondaryText)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(pro.isUnlocked
                            ? Text(theme.name)
                            : Text("\(theme.name), Pro-functie, vergrendeld"))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(pro.isUnlocked
                           ? Text("Selecteer kleurenthema")
                           : Text("Ontgrendel met Roundly Pro"))
    }

    /// Pro gate: free users tapping a *locked* theme get the paywall; the
    /// already-active theme is theirs regardless of Pro, so tapping it is a
    /// no-op rather than a paywall dead-end.
    private func selectTheme(_ theme: PhaseTheme) {
        guard appearance.phaseThemeID != theme.id else { return }
        if pro.isUnlocked {
            appearance.phaseThemeID = theme.id
        } else {
            showPaywall = true
        }
    }

    private func appearanceRow(mode: AppearanceMode, selected: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.coral.opacity(0.15))
                    .frame(width: 30, height: 30)
                Image(systemName: mode.icon)
                    .foregroundStyle(AppTheme.coral)
                    .font(.caption)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(mode.displayName)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(AppTheme.primaryText)
                Text(mode.subtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer()
            if selected {
                Image(systemName: "checkmark")
                    .foregroundStyle(AppTheme.coral)
                    .font(.callout.weight(.semibold))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - Helpers
    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(AppTheme.secondaryText)
            .padding(.leading, 8)
    }

    private func toggleRow(icon: String, tint: Color, label: LocalizedStringKey, sub: LocalizedStringKey, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(tint.opacity(0.18)).frame(width: 30, height: 30)
                Image(systemName: icon).foregroundStyle(tint).font(.caption)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(.body, design: .rounded)).foregroundStyle(AppTheme.primaryText)
                Text(sub).font(.system(.caption, design: .rounded)).foregroundStyle(AppTheme.secondaryText)
            }
            Spacer()
            Toggle(label, isOn: isOn).tint(AppTheme.coral).labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

}

#Preview {
    AccountView()
        .environment(AudioSettings())
        .environment(AppearanceSettings())
        .environment(StoreManager())
        .modelContainer(for: WorkoutEntity.self, inMemory: true)
}
