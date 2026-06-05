import SwiftUI
import AuthenticationServices

struct AccountView: View {
    @Environment(AudioSettings.self) private var audioSettings
    @Environment(AuthManager.self) private var auth
    @Environment(AppearanceSettings.self) private var appearance
    @Environment(\.modelContext) private var modelContext

    @State private var showAuthErrorAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        profileCard
                        signalSection
                        appearanceSection
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
                Button("OK", role: .cancel) { auth.errorMessage = nil }
            } message: {
                Text(auth.errorMessage ?? "")
            }
        }
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
                        Text("Log in met Apple om je favorieten te bewaren op al je apparaten.")
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
                        request.requestedScopes = [.fullName, .email]
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

    // MARK: - Logout
    private var logoutButton: some View {
        Group {
            if auth.isSignedIn {
                Button(role: .destructive) {
                    auth.signOut(modelContext: modelContext)
                } label: {
                    Text("Log out")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule().stroke(AppTheme.error.opacity(0.4), lineWidth: 1))
                        .foregroundStyle(AppTheme.error)
                }
                .padding(.top, 4)
            }
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
}
