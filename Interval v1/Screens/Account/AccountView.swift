import SwiftUI
import AuthenticationServices

struct AccountView: View {
    @Environment(AudioSettings.self) private var audioSettings
    @Environment(AuthManager.self) private var auth
    @Environment(AppearanceSettings.self) private var appearance
    @Environment(StoreManager.self) private var pro
    @Environment(\.modelContext) private var modelContext

    @State private var showAuthErrorAlert = false
    @State private var showPaywall = false
    @State private var restoreInFlight = false
    @State private var showDeleteConfirm = false
    @State private var deleteInFlight = false
    @State private var showDeleteError = false
    @State private var deleteErrorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        profileCard
                        // Pro upgrade/restore card is hidden while the app
                        // ships free (StoreManager.freeForEveryone). Colour
                        // themes below are simply a free feature now.
                        if !StoreManager.freeForEveryone { proSection }
                        signalSection
                        appearanceSection
                        themeSection
                        logoutButton
                    }
                    .padding(20)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Account")
            // Observe errorVersion (monotonic counter) instead of errorMessage
            // so an identical error string thrown twice still re-presents.
            .onChange(of: auth.errorVersion) { _, _ in
                if auth.errorMessage != nil { showAuthErrorAlert = true }
            }
            .alert("Inloggen mislukt", isPresented: $showAuthErrorAlert) {
                Button("OK", role: .cancel) { auth.clearError() }
            } message: {
                Text(auth.errorMessage ?? "")
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    // MARK: - Pro
    private var proSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Interval Pro")
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(AppTheme.coral.opacity(0.18)).frame(width: 36, height: 36)
                        Image(systemName: pro.isUnlocked ? "checkmark.seal.fill" : "heart.fill")
                            .foregroundStyle(AppTheme.coral)
                            .font(.callout)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pro.isUnlocked ? "Interval Pro actief" : "Bewaar je favorieten")
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

    // MARK: - Profile
    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(AppTheme.workGradient).frame(width: 64, height: 64)
                    if let initials = userInitials {
                        Text(initials)
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: "person.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    if auth.isSignedIn {
                        if let fullName = auth.user?.fullName, !fullName.isEmpty {
                            Text(fullName)
                                .font(.system(.title3, design: .rounded, weight: .bold))
                                .foregroundStyle(AppTheme.primaryText)
                        } else {
                            Text("Ingelogd met Apple")
                                .font(.system(.title3, design: .rounded, weight: .bold))
                                .foregroundStyle(AppTheme.primaryText)
                        }
                        if let email = auth.user?.email, !email.isEmpty {
                            Text(email)
                                .font(.system(.footnote, design: .rounded))
                                .foregroundStyle(AppTheme.secondaryText)
                                .lineLimit(1)
                        } else {
                            Label("Trainingen worden gesyncd", systemImage: "checkmark.icloud.fill")
                                .font(.system(.footnote, design: .rounded))
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    } else {
                        Text("Sync je trainingen")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(AppTheme.primaryText)
                        Text("Inloggen is optioneel. De app werkt volledig zonder account — log alleen in met Apple als je je favorieten tussen apparaten wilt synchroniseren.")
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(AppTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
            }

            if !auth.isSignedIn {
                SignInWithAppleButton(
                    .signIn,
                    onRequest: { request in
                        auth.configureSignInRequest(request)
                    },
                    onCompletion: { result in
                        auth.handleAuthorization(result)
                    }
                )
                .signInWithAppleButtonStyle(.black)
                .frame(height: 48)
                .clipShape(Capsule())
            }
        }
        .padding(20)
        .softCard()
        .animation(.appSmooth, value: auth.isSignedIn)
    }

    private var userInitials: String? {
        guard let name = auth.user?.fullName, !name.isEmpty else { return nil }
        let parts = name.split(separator: " ").prefix(2)
        let initials = parts.map { $0.prefix(1) }.joined().uppercased()
        return initials.isEmpty ? nil : initials
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
                           : Text("Ontgrendel met Interval Pro"))
    }

    /// Pro gate: free users tapping any theme get the paywall; Pro users select.
    private func selectTheme(_ theme: PhaseTheme) {
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

    // MARK: - Logout & account deletion
    private var logoutButton: some View {
        Group {
            if auth.isSignedIn {
                VStack(spacing: 14) {
                    Button(role: .destructive) {
                        auth.signOut(modelContext: modelContext)
                    } label: {
                        Text("Log uit")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Capsule().stroke(AppTheme.error.opacity(0.4), lineWidth: 1))
                            .foregroundStyle(AppTheme.error)
                    }

                    // Required by App Store Review Guideline 5.1.1(v): a user
                    // who can create an account must be able to delete it
                    // in-app. Double-confirmed because it's irreversible.
                    Button {
                        showDeleteConfirm = true
                    } label: {
                        HStack(spacing: 6) {
                            if deleteInFlight { ProgressView().tint(AppTheme.error) }
                            Text("Account verwijderen")
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(AppTheme.error)
                    }
                    .disabled(deleteInFlight)
                }
                .padding(.top, 4)
                .alert("Account verwijderen?", isPresented: $showDeleteConfirm) {
                    Button("Verwijder", role: .destructive) {
                        Task { await deleteAccount() }
                    }
                    Button("Annuleer", role: .cancel) {}
                } message: {
                    Text("Dit verwijdert je account en al je gesynchroniseerde favorieten definitief. Dit kan niet ongedaan worden gemaakt.")
                }
                .alert("Verwijderen mislukt", isPresented: $showDeleteError) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(deleteErrorMessage ?? "Probeer het later opnieuw.")
                }
            }
        }
    }

    private func deleteAccount() async {
        deleteInFlight = true
        defer { deleteInFlight = false }
        do {
            try await auth.deleteAccount(modelContext: modelContext)
        } catch {
            // Raw SDK errors are technical English strings — give the user
            // an actionable Dutch message instead. The most common real
            // cause is a missing/expired Supabase session (e.g. signed in
            // with Apple while offline), fixed by signing in again.
            deleteErrorMessage = String(localized: "Verwijderen is niet gelukt. Controleer je internetverbinding, log zo nodig opnieuw in met Apple en probeer het dan nog eens.")
            showDeleteError = true
        }
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
        .environment(AuthManager())
        .environment(AppearanceSettings())
        .environment(StoreManager())
        .modelContainer(for: WorkoutEntity.self, inMemory: true)
}
